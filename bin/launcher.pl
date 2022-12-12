#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw( $Bin );
use Pod::Usage;
use Getopt::Long;

use lib "$Bin/../lib";
use Util::Config;
use Launcher;

our $VERSION = '0.1';

#
# read input args
#

my %input = ();
GetOptions(
    \%input,
    'help=i',
    'command=s',
) or pod2usage('Fix arguments');

if ( $input{help} ) {
    pod2usage(
        -verbose   => 1,
        -exitval   => 1,
        -noperldoc => 1,
    );
}
elsif ( !exists $input{command} ) {
    if ( -t STDIN ) {
        pod2usage(
            -verbose   => 0,
            -exitval   => 1,
            -noperldoc => 1,
        );
    }
    else {
        Launcher->tellme('Abort: i need command');
        exit 1;
    }
}

#
# read config
#

my $o_conf = Util::Config::get_config(
    file => $Bin . '/../launcher.conf',
);

#
# process data
#

my $method = lc $input{command}; # to make perl critic happy
if ( !Launcher->can($method) ) {
    Launcher->tellme( 'Abort: unexpected command "' . $input{command} . q{"} );
    exit 1;
}

Launcher->$method($o_conf);

exit;

__END__

=for stopwords Launcher Oleksii Grynevych rsync

=head1 NAME

  launcher.pl - start/stop script

=head1 USAGE

  launcher.pl [options]

  Example:
  ./launcher.pl --command=start

=head1 OPTIONS

  Options:
   --help          Full help text
   --command       [REQUIRED] start | stop | rsync

=head1 ARGUMENTS

  Available arguments for command:
    start
    stop
    rsync

=head1 DESCRIPTION

This program will start or stop application as background process or rsync files after git pull

=head1 AUTHOR

Oleksii Grynevych <grinevich@gmail.com>

=cut
