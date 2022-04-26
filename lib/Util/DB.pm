package Util::DB;

use strict;
use warnings;

use DBI;
use Carp qw(croak);

our $VERSION = '1.1';

sub get_dbh {
    my (%args) = @_;

    my $db_name = $args{db_name};
    my $db_user = $args{db_user};
    my $db_pass = $args{db_pass};

    ## no critic (Variables::ProhibitPackageVars)
    my $dbh = DBI->connect(
        'DBI:mysql:database=' . $db_name,
        $db_user,
        $db_pass,
        {
            RaiseError => 1,
            AutoCommit => 1,
            # mariadb_auto_reconnect => 1,
            # mariadb_server_prepare => 0,
        }
    ) or croak $DBI::errstr;
    ## use critic

    $dbh->do(q{SET NAMES 'utf8'});
    return $dbh;
}

1;
