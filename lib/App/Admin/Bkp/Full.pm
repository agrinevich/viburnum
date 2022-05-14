package App::Admin::Bkp::Full;

use strict;
use warnings;

use POSIX ();
use POSIX qw(strftime);

use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;
    my $domain   = $app->config->{site}->{domain};
    my $bkp_path = $app->config->{bkp}->{path};

    my $bkp_name  = $domain . '_' . strftime( '%Y%m%d-%H%M%S', localtime );
    my $file_name = $bkp_name . '.zip';
    my $bkp_file  = $root_dir . $bkp_path . q{/} . $file_name;

    my $h_zip = Util::Files::create_zip(
        src_dir => $root_dir,
        dst_dir => $root_dir . $bkp_path,
        name    => $bkp_name,
    );

    return {
        url => $app->config->{site}->{host} . '/admin/bkp?msg=success',
    };
}

1;
