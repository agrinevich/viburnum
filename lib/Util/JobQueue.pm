package Util::JobQueue;

use strict;
use warnings;

use TheSchwartz;
use Data::ObjectDriver::Driver::DBI;

our $VERSION = '1.1';

# sub db_name {
#     return 'schwartz';
# }

sub new_client {
    my (%args) = @_;

    my $driver = Data::ObjectDriver::Driver::DBI->new( dbh => $args{dbh} );

    # my $databaseref = [
    #     {
    #         # dsn  => 'DBI:mysql:database=' . db_name(),
    #         dsn  => $args{db_name},
    #         user => $args{db_user},
    #         pass => $args{db_pass},
    #     },
    # ];

    return TheSchwartz->new(
        # databases  => $databaseref,
        databases  => [ { driver => $driver } ],
        verbose    => 0,
        prioritize => 1,
        # batch_size => 2,
    );
}

sub new_job {
    my ($h_params) = @_;

    my $uniqkey  = $h_params->{uniqkey};
    my $funcname = $h_params->{funcname};
    my $h_args   = $h_params->{args};

    my $job = TheSchwartz::Job->new(
        uniqkey  => $uniqkey,
        funcname => $funcname,
        arg      => [
            %{$h_args},
        ],
    );

    return $job;
}

1;
