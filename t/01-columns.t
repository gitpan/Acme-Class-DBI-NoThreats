use strict;
use Test::More tests => 35;

#-----------------------------------------------------------------------
# Make sure that we can set up columns properly
#-----------------------------------------------------------------------
package State;

use base 'Acme::Class::DBI::NoThreats';

State->table('State');
State->columns('Primary',   'Name');
State->columns('Essential', qw/Abbreviation/);
State->columns('Weather',   qw/Rain Snowfall/);
State->columns('Other',     qw/Capital Population/);
State->has_many(cities => "City");

sub accessor_name {
	my ($class, $column) = @_;
	my $return = $column eq "Rain" ? "Rainfall" : $column;
	return $return;
}

sub mutator_name {
	my ($class, $column) = @_;
	my $return = $column eq "Rain" ? "set_Rainfall" : "set_$column";
	return "set_$column";
}

sub Snowfall { 1 }


package City;

use base 'Acme::Class::DBI::NoThreats';

City->table('City');
City->columns(All => qw/Name State Population/);
City->has_a(State => 'State');


#-------------------------------------------------------------------------
package CD;
use base 'Acme::Class::DBI::NoThreats';

CD->table('CD');
CD->columns('All' => qw/artist title length/);

#-------------------------------------------------------------------------

package main;

is(State->table,          'State', 'State table()');
is(State->primary_column, 'name',  'State primary()');
is_deeply [ State->columns('Primary') ] => [qw/name/],
	'State Primary:' . join ", ", State->columns('Primary');
is_deeply [ sort State->columns('Essential') ] => [qw/abbreviation name/],
	'State Essential:' . join ", ", State->columns('Essential');
is_deeply [ sort State->columns('All') ] =>
	[ sort qw/name abbreviation rain snowfall capital population/ ],
	'State All:' . join ", ", State->columns('All');

is(CD->primary_column, 'artist', 'CD primary()');
is_deeply [ CD->columns('Primary') ] => [qw/artist/],
	'CD primary:' . join ", ", CD->columns('Primary');
is_deeply [ sort CD->columns('All') ] => [qw/artist length title/],
	'CD all:' . join ", ", CD->columns('All');
is_deeply [ sort CD->columns('Essential') ] => [qw/artist/],
	'CD essential:' . join ", ", CD->columns('Essential');

{
	local $SIG{__WARN__} = sub { ok 1, "Error thrown" };
	ok(!State->columns('Nonsense'), "No Nonsense group");
	ok(State->is_column('capital'), 'is_column deprecated');
}
ok(State->find_column('Rain'), 'find_column Rain');
ok(State->find_column('rain'), 'find_column rain');
ok(!State->find_column('HGLAGAGlAG'), '!find_column HGLAGAGlAG');

ok(!State->can('Rain'), 'No Rain accessor set up');
ok(State->can('Rainfall'),           'Rainfall accessor set up');
ok(State->can('_Rainfall_accessor'), ' with correct alias');
ok(!State->can('_Rain_accessor'), ' (not by colname)');
ok(!State->can('rain'),           ' (not normalized)');
ok(State->can('set_Rain'),           'overriden mutator');
ok(State->can('_set_Rain_accessor'), ' with alias');

ok(State->can('Snowfall'),           'overridden accessor set up');
ok(State->can('_Snowfall_accessor'), ' with alias');
ok(!State->can('snowfall'), ' (not normalized)');
ok(State->can('set_Snowfall'),           'overriden mutator');
ok(State->can('_set_Snowfall_accessor'), ' with alias');

{
	eval { my @grps = State->__grouper->groups_for("Huh"); };
	ok $@, "Huh not in groups";

	my @grps = sort State->__grouper->groups_for(State->_find_columns(qw/rain capital/));
	is @grps, 2, "Rain and Capital = 2 groups";
	is $grps[0], 'Other',   " - Other";
	is $grps[1], 'Weather', " - Weather";
}

{
	local $SIG{__WARN__} = sub { };
	eval { Acme::Class::DBI::NoThreats->retrieve(1) };
	like $@, qr/Can't retrieve unless primary columns are defined/, "Need primary key for retrieve";
}

#-----------------------------------------------------------------------
# Make sure that columns inherit properly
#-----------------------------------------------------------------------
package State;

package A;
@A::ISA = qw(Acme::Class::DBI::NoThreats);
__PACKAGE__->columns(Primary => 'id');

package A::B;
@A::B::ISA = 'A';
__PACKAGE__->columns(All => qw(id b1));

package A::C;
@A::C::ISA = 'A';
__PACKAGE__->columns(All => qw(id c1 c2 c3));

package main;
is join (' ', sort A->columns),    'id',          "A columns";
is join (' ', sort A::B->columns), 'b1 id',       "A::B columns";
is join (' ', sort A::C->columns), 'c1 c2 c3 id', "A::C columns";
