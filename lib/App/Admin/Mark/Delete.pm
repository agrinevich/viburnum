package App::Admin::Mark::Delete;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;

    $app->dbh->do("DELETE FROM global_marks WHERE id = $id");

    return {
        url => $app->config->{site}->{host} . '/admin/mark',
    };
}

1;
