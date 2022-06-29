package Util::HTTP;

use strict;
use warnings;

use HTTP::Tiny;
use JSON::PP;
use Carp qw(croak);

our $VERSION = '1.1';

sub request {
    my (%args) = @_;

    my $h_params = $args{params};
    my $api_url  = $args{api_url};

    my $http     = HTTP::Tiny->new();
    my $params   = $http->www_form_urlencode($h_params);
    my $response = $http->get( $api_url . q{?} . $params );

    my $decoded = decode_json( $response->{content} );
    $response->{content} = $decoded;

    return $response;
}

1;
