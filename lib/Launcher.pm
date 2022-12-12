package Launcher;

use strict;
use warnings;
use feature qw( say );

use Carp qw( croak );
use English qw( -no_match_vars );
use POSIX qw( strftime );
use Scalar::Util qw( reftype );
use Data::Dumper;
use FileHandle;

use constant {
    EXECFAIL => -1,
    CHILDSIG => 127,
};

our $VERSION = '0.1';

sub start {
    my ( undef, $o_conf ) = @_;

    _starman(
        port      => $o_conf->{starman}->{aport},
        workers   => $o_conf->{starman}->{workers},
        dir       => $o_conf->{starman}->{dir},
        pidfile   => '/tmp/admin.pid',
        errorlog  => '/log/admin-error.log',
        accesslog => '/log/admin-access.log',
        appfile   => '/bin/admin.psgi',
    );

    _starman(
        port      => $o_conf->{starman}->{uport},
        workers   => $o_conf->{starman}->{workers},
        dir       => $o_conf->{starman}->{dir},
        pidfile   => '/tmp/user.pid',
        errorlog  => '/log/user-error.log',
        accesslog => '/log/user-access.log',
        appfile   => '/bin/user.psgi',
    );

    my $err = _call_system(
        call => $o_conf->{starman}->{dir} . '/bin/jqctl.pl start',
    );
    my $msg = $err ? $err : 'job queue started';
    tellme( undef, $msg );

    return;
}

sub _starman {
    my (%args) = @_;

    my $p   = $args{port};
    my $w   = $args{workers};
    my $dir = $args{dir};
    my $pf  = $dir . $args{pidfile};
    my $el  = $dir . $args{errorlog};
    my $al  = $dir . $args{accesslog};
    my $af  = $dir . $args{appfile};

    my $err = _call_system(
        call =>
            "starman --daemonize --port $p --workers $w --pid $pf --error-log $el --access-log $al $af",
    );

    my $msg = $err ? $err : $af . ' started';
    tellme( undef, $msg );

    return;
}

sub rsync {
    my ( undef, $o_conf ) = @_;

    my $srcdir   = $o_conf->{rsync}->{src};
    my $dstdir   = $o_conf->{rsync}->{dst};
    my $exclfile = $o_conf->{rsync}->{exclude};

    my $call = "rsync -a --exclude-from='$exclfile' $srcdir $dstdir";
    tellme( undef, $call );

    my $err = _call_system(
        call => $call,
    );
    my $msg = $err ? $err : 'rsync done';
    tellme( undef, $msg );

    return 1;
}

sub stop {
    my ( undef, $o_conf ) = @_;

    my $dir = $o_conf->{starman}->{dir};

    _kill_process(
        pidfile => $dir . '/tmp/admin.pid',
    );

    _kill_process(
        pidfile => $dir . '/tmp/user.pid',
    );

    my $err = _call_system(
        call => $dir . '/bin/jqctl.pl stop',
    );
    my $msg = $err ? $err : 'job queue stopped';
    tellme( undef, $msg );

    return;
}

sub _kill_process {
    my (%args) = @_;

    my $pidfile = $args{pidfile};

    if ( !-e $pidfile ) {
        return "File $pidfile - not found, skip";
    }

    my $fh = FileHandle->new;
    my $pid;
    if ( $fh->open("< $pidfile") ) {
        my @lines = $fh->getlines;
        $fh->close;
        $pid = $lines[0];
    }

    if ( !$pid ) {
        return "Failed to read PID from file - $pidfile, skip";
    }

    chomp $pid;

    my $err = _call_system(
        call    => "kill -s QUIT $pid",
        purpose => 'kill ' . $pid,
    );
    my $msg = $err ? $err : $pidfile . ' killed';
    tellme( undef, $msg );

    return;
}

sub _call_system {
    my (%args) = @_;

    system $args{call};

    if ( $CHILD_ERROR == EXECFAIL ) {
        return "failed to execute: $OS_ERROR\n";
    }
    elsif ( $CHILD_ERROR & CHILDSIG ) {
        my $sig = $CHILD_ERROR & CHILDSIG;
        return "child died with signal $sig\n";
    }

    return;
}

#
# some helpers
#

sub tellme {
    my ( undef, $input ) = @_;

    my $str;
    if   ( !reftype $input ) { $str = $input; }
    else                     { $str = Dumper($input); }

    say _fmt4log($str) or croak 'Abort: failed to say';

    return;
}

sub _fmt4log {
    my ($str) = @_;

    return sprintf '%s - %s', _timenow(), $str;
}

sub _timenow {
    return strftime '%Y-%b-%e %H:%M:%S', localtime;
}

1;
