package App::Admin::Good::Import::Upraw;

use strict;
use warnings;

use English qw( -no_match_vars );
use Carp qw(croak carp);

use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $h_uploads = $o_request->uploads();

    my $o_file    = $h_uploads->{file};
    my $file_tmp  = $o_file->path();
    my $file_name = $o_file->basename();

    my $root_dir = $app->root_dir();
    my $path     = $app->config->{data}->{prices_path} . '/raw';
    my $dst_dir  = $root_dir . $path;
    if ( !-d $dst_dir ) {
        Util::Files::make_path( path => $dst_dir );
    }
    my $file_raw = $dst_dir . "/$file_name";

    rename $file_tmp, $file_raw or croak $OS_ERROR;

    my $url = $app->config->{site}->{host} . '/admin/good/import';

    return {
        url => $url,
    };
}

1;
