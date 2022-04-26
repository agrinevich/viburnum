package App::Admin::Cat::Markdel;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;
    my $page_id  = $o_params->{page_id} || 0;

    $app->dbh->do("DELETE FROM page_marks WHERE id = $id");

    return {
        url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $page_id,
    };
}

1;
