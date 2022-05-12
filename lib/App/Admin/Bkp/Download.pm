package App::Admin::Bkp::Download;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $bkp_name = $o_params->{name} || q{};

    my $root_dir = $app->root_dir;
    my $bkp_path = $app->config->{bkp}->{path};
    my $bkp_file = $root_dir . $bkp_path . q{/} . $bkp_name . '.zip';

    if ( !e $bkp_file) {
        return {
            url => $app->config->{site}->{host} . '/admin/bkp?msg=error',
        };
    }

    #
    #
    #
    my $fh             = 'foo';
    my $content_length = -s $bkp_file;
    # do {
    #     use bytes;
    # }

    return {
        # url => $app->config->{site}->{host} . '/admin/bkp?msg=success',
        body           => $fh,
        content_length => $content_length,
    };
}

1;
