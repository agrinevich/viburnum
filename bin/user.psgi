#!/usr/bin/perl

use strict;
use warnings;

use Plack;
use Plack::Builder;
use Plack::Middleware::ReverseProxy;
use Plack::Middleware::RealIP;
use FindBin qw($Bin);

use lib "$Bin/../lib";
use App::User;

our $VERSION = '1.1';

my $app = sub {
    my $env = shift;

    my $o_response = App::User->new(
        root_dir  => "$Bin/..",
        conf_file => 'main.conf',
        log_file  => 'user-error.log',
    )->run($env);

    return $o_response->finalize();
};

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 'Plack::Middleware::ReverseProxy';
    enable 'Plack::Middleware::RealIP', header => 'X-Forwarded-For';
    # trusted_proxy => [qw(192.168.1.0/24 192.168.2.1)];
    $app;
};
