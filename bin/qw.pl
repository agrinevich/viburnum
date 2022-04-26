#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use App::Worker;

our $VERSION = '1.1';

#
# Job Queue worker app
#

App::Worker->new(
    root_dir  => "$Bin/..",
    conf_file => 'main.conf',
    log_file  => 'qw.log',
)->run();

exit;
