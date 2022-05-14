package App::Admin::Bkp::Delete;

use strict;
use warnings;

use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $file_name = $o_params->{name} || q{};

    my $root_dir = $app->root_dir;
    my $bkp_path = $app->config->{bkp}->{path};

    my $zip = $root_dir . $bkp_path . q{/} . $file_name;
    unlink $zip;

    return {
        url => $app->config->{site}->{host} . '/admin/bkp?msg=success',
    };
}

1;
