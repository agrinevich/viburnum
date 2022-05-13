package App::Admin::Bkp::Upload;

use strict;
use warnings;

use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $o_uploads = $o_request->uploads();

    my $file = $o_uploads->{file};

    my $root_dir = $app->root_dir;
    my $bkp_path = $app->config->{bkp}->{path};

    my $file_tmp = $file->path();

    my $file_name = $file->basename;
    my $file_dst  = $root_dir . $bkp_path . q{/} . $file_name;

    rename $file_tmp, $file_dst;

    #
    # TODO: move extraction to Restore
    #
    my $err = Util::Files::extract_zip(
        file    => $file_dst,
        dst_dir => $root_dir . $bkp_path,
    );
    if ($err) {
        $app->logger->error($err);
    }

    return {
        url => $app->config->{site}->{host} . '/admin/bkp',
    };
}

1;
