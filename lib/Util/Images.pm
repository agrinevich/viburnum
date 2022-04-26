package Util::Images;

use strict;
use warnings;

use Try::Tiny;
use Imager;
use Carp qw(carp croak);

our $VERSION = '1.1';

sub scale_image {
    my (%args) = @_;

    my $file_src = $args{file_src};
    my $file_dst = $args{file_dst};
    my $width    = $args{width};
    my $height   = $args{height};

    my $is_ok = try {
        my $o_image_src = Imager->new() or croak 'Failed to read: ' . Imager->errstr();

        $o_image_src->read(
            file => $file_src,
        ) or croak 'Failed to read: ' . $o_image_src->errstr;

        my $o_image_dst = $o_image_src->scale(
            xpixels => $width,
            ypixels => $height,
            type    => 'min',
        );

        $o_image_dst->write(
            file => $file_dst,
        ) or croak 'Failed to save: ', $o_image_dst->errstr;

        return 1;
    }
    catch {
        carp("Failed to scale_image: $_");
        return;
    };

    return $is_ok;
}

1;
