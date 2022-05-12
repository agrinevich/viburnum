package App::Admin::Bkp::Delete;

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
    my $bkp_dir  = $root_dir . $bkp_path . q{/} . $bkp_name;

    my $dst_dir = $bkp_dir . '/tpl';
    if ( -d $dst_dir ) {
        Util::Files::empty_dir_recursive(
            dir => $dst_dir,
        );
        rmdir $dst_dir;
    }

    my $dst_dir2 = $bkp_dir . '/sql';
    if ( -d $dst_dir2 ) {
        Util::Files::empty_dir_recursive(
            dir => $dst_dir2,
        );
        rmdir $dst_dir2;
    }

    rmdir $bkp_dir;

    my $zip = $root_dir . $bkp_path . q{/} . $bkp_name . '.zip';
    unlink $zip;

    return {
        url => $app->config->{site}->{host} . '/admin/bkp?msg=success',
    };
}

1;
