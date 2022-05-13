package App::Admin::Bkp::Download;

use strict;
use warnings;

use Util::Files;

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

    if ( !-e $bkp_file ) {
        return {
            url => $app->config->{site}->{host} . '/admin/bkp?msg=error',
        };
    }

    my $fh = Util::Files::file_handle(
        file    => $bkp_file,
        mode    => q{<},
        binmode => q{:raw},
    );

    return {
        body             => $fh,
        is_encoded       => 1,
        content_type     => 'application/zip',
        file_name        => $bkp_name . '.zip',
        content_encoding => 'zip',
    };
}

1;
