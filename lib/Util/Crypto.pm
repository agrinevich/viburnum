package Util::Crypto;

use strict;
use warnings;

use Digest::SHA qw(sha1_hex);

our $VERSION = '1.1';

sub get_sha1_hex {
    my (%args) = @_;

    my $str = $args{str};

    my $digest = sha1_hex($str);

    return $digest;
}

1;
