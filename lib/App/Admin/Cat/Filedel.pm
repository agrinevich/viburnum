package App::Admin::Cat::Filedel;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $name     = $o_params->{name} || q{};
    my $path     = $o_params->{path} || q{};
    my $page_id  = $o_params->{page_id} || 0;

    my $root_dir  = $app->root_dir;
    my $html_path = $app->config->{data}->{html_path};
    my $file      = $root_dir . $html_path . $path . q{/} . $name;

    unlink $file;

    return {
        url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $page_id,
    };
}

1;
