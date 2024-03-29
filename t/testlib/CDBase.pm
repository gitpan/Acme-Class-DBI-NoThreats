package CDBase;

use strict;
use base qw(Acme::Class::DBI::NoThreats);

use File::Temp qw/tempfile/;
my (undef, $DB) = tempfile();
my @DSN = ("dbi:SQLite:dbname=$DB", '', '', { AutoCommit => 1 });

END { unlink $DB if -e $DB }

__PACKAGE__->connection(@DSN);

1;
