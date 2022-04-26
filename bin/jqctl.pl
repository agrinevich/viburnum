#!/usr/bin/perl

#
# Job Queue manager (for qw.pl)
#
# ./bin/jqctl.pl start
# ./bin/jqctl.pl stop

use strict;
use warnings;

use Daemon::Control;
use FindBin qw($Bin);
use lib "$Bin/../lib";

our $VERSION = '1.1';

my $qw = Daemon::Control->new(
    name         => 'Job Queue worker daemon',
    path         => "$Bin/jqctl.pl",
    fork         => 2,
    stop_signals => [ 'TERM', 'TERM', 'TERM' ],
    kill_timeout => 7,
    help         => 'Short manual text here',

    program => "$Bin/qw.pl",

    pid_file    => "$Bin/../tmp/qw.pid",
    stdout_file => "$Bin/../log/qw.log",
    stderr_file => "$Bin/../log/qw.log",
);
my $qw_exit = $qw->run_command(@ARGV);

exit $qw_exit;
