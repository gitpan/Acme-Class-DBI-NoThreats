use strict;
use Test::More;

BEGIN {
	eval "use DBD::SQLite";
	plan $@ ? (skip_all => 'needs DBD::SQLite for testing') : (tests => 55);
}

INIT {
	local $SIG{__WARN__} =
		sub { like $_[0], qr/clashes with built-in method/, $_[0] };
	use lib 't/testlib';
	require Film;
	require Actor;
	Film->create_movies_table;
	Actor->create_actors_table;
	Actor->has_a(film => 'Film');
	sub Acme::Class::DBI::NoThreats::sheep { ok 0; }
}

sub Film::mutator_name {
	my ($class, $col) = @_;
	return "set_sheep" if lc $col eq "numexplodingsheep";
	return $col;
}

sub Film::accessor_name {
	my ($class, $col) = @_;
	return "sheep" if lc $col eq "numexplodingsheep";
	return $col;
}

sub Actor::accessor_name {
	my ($class, $col) = @_;
	return "movie" if lc $col eq "film";
	return $col;
}

my $data = {
	Title    => 'Bad Taste',
	Director => 'Peter Jackson',
	Rating   => 'R',
};

eval {
	my $data = $data;
	$data->{NumExplodingSheep} = 1;
	ok my $bt = Film->create($data), "Modified accessor - with column name";
	isa_ok $bt, "Film";
};
is $@, '', "No errors";

eval {
	my $data = $data;
	$data->{sheep} = 1;
	ok my $bt = Film->create($data), "Modified accessor - with accessor";
	isa_ok $bt, "Film";
};
is $@, '', "No errors";

eval {
	my @film = Film->search({ sheep => 1 });
	is @film, 2, "Can search with modified accessor";
};

{

	eval {
		local $data->{set_sheep} = 1;
		ok my $bt = Film->create($data), "Modified mutator - with mutator";
		isa_ok $bt, "Film";
	};
	is $@, '', "No errors";

	eval {
		local $data->{NumExplodingSheep} = 1;
		ok my $bt = Film->create($data), "Modified mutator - with column name";
		isa_ok $bt, "Film";
	};
	is $@, '', "No errors";

	eval {
		local $data->{sheep} = 1;
		ok my $bt = Film->create($data), "Modified mutator - with accessor";
		isa_ok $bt, "Film";
	};
	is $@, '', "No errors";

}

{
	my $p_data = {
		name => 'Peter Jackson',
		film => 'Bad Taste',
	};
	my $bt = Film->create($data);
	my $ac = Actor->create($p_data);

	eval { my $f = $ac->film };
	like $@, qr/Can't locate object method "film"/, "no hasa film";

	eval {
		ok my $f = $ac->movie, "hasa movie";
		isa_ok $f, "Film";
		is $f->id, $bt->id, " - Bad Taste";
	};
	is $@, '', "No errors";

	{
		local $data->{Title} = "Another film";
		my $film = Film->create($data);

		eval { $ac->film($film) };
		ok $@, $@;

		eval { $ac->movie($film) };
		ok $@, $@;

		eval {
			ok $ac->set_film($film), "Set movie through hasa";
			$ac->update;
			ok my $f = $ac->movie, "hasa movie";
			isa_ok $f, "Film";
			is $f->id, $film->id, " - Another Film";
		};
		is $@, '', "No problem";
	}

}

{    # have non persistent accessor?
	Film->columns(TEMP => qw/nonpersistent/);
	ok(Film->find_column('nonpersistent'), "nonpersistent is a column");
	ok(!Film->has_real_column('nonpersistent'), " - but it's not real");

	{
		my $film = Film->create({ Title => "Veronique", nonpersistent => 42 });
		is $film->title,         "Veronique", "Title set OK";
		is $film->nonpersistent, 42,          "As is non persistent value";
		$film->remove_from_object_index;
		ok $film = Film->retrieve('Veronique'), "Re-retrieve film";
		is $film->title, "Veronique", "Title still OK";
		is $film->nonpersistent, undef, "Non persistent value gone";
		ok $film->nonpersistent(40), "Can set it";
		is $film->nonpersistent, 40, "And it's there again";
		ok $film->update, "Commit the film";
		is $film->nonpersistent, 40, "And it's still there";
	}
}

{    # was bug with TEMP and no Essential
	is_deeply(
		Actor->columns('Essential'),
		Actor->columns('Primary'),
		"Actor has no specific essential columns"
	);
	ok(Actor->find_column('nonpersistent'), "nonpersistent is a column");
	ok(!Actor->has_real_column('nonpersistent'), " - but it's not real");
	my $pj = eval { Actor->search(name => "Peter Jackson")->first };
	is $@, '', "no problems retrieving actors";
	isa_ok $pj => "Actor";
}

{
	Film->autoupdate(1);
	my $naked = Film->create({ title => 'Naked' });
	my $sandl = Film->create({ title => 'Secrets and Lies' });

	my $rating = 1;
	my $update_failure = sub {
		my $obj = shift;
		eval { $obj->rating($rating++) };
		return $@ =~ /read only/;
	};

	ok !$update_failure->($naked), "Can update Naked";
	ok $naked->make_read_only, "Make Naked read only";
	ok $update_failure->($naked), "Can't update Naked any more";
	ok !$update_failure->($sandl), "But can still update Secrets and Lies";
	my $july4 = eval { Film->create({ title => "4 Days in July" }) };
	isa_ok $july4 => "Film", "And can still create new films";

	ok(Film->make_read_only, "Make all Films read only");
	ok $update_failure->($naked), "Still can't update Naked";
	ok $update_failure->($sandl), "And can't update S&L any more";
	eval { $july4->delete };
	like $@, qr/read only/, "And can't delete 4 Days in July";
	my $abigail = eval { Film->create({ title => "Abigail's Party" }) };
	like $@, qr/read only/, "Or create new films";
	$SIG{__WARN__} = sub { };
}

