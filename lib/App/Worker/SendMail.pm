package App::Worker::SendMail;

use strict;
use warnings;

use parent qw( TheSchwartz::Worker );
use TheSchwartz::Job;

use Try::Tiny;
use Email::Stuffer;
use Email::Sender::Transport::SMTP qw();
use Carp qw(croak carp);

use Util::Config;
use Util::DB;

our $VERSION = '1.1';

sub work {
    my ( undef, $job ) = @_;

    my %args = @{ $job->arg };

    my $body  = $args{body};
    my $subj  = $args{subj};
    my $rcp   = $args{rcp};
    my $snd   = $args{snd};
    my $host  = $args{host};
    my $port  = $args{port};
    my $ssl   = $args{ssl};
    my $user  = $args{user};
    my $pass  = $args{pass};
    my $debug = $args{debug};

    if ( !$rcp ) {
        carp('Failed to SendMail: no recipient');
        $job->failed('Failed to SendMail: no recipient');
        return;
    }

    my $transport = Email::Sender::Transport::SMTP->new(
        {
            debug         => $debug,
            host          => $host,
            port          => $port,
            sasl_username => $user,
            sasl_password => $pass,
            ssl           => $ssl,
        }
    );
    if ( !$transport ) {
        carp('SendMail transport failed');
        $job->failed('SendMail transport failed');
        return;
    }

    my $stuffer = Email::Stuffer->new(
        {
            to        => $rcp,
            from      => $snd,
            subject   => $subj,
            text_body => $body,
            transport => $transport,
        }
    );
    if ( !$stuffer ) {
        carp('SendMail Email::Stuffer failed');
        $job->failed('SendMail Email::Stuffer failed');
        return;
    }

    my $is_ok = try {
        $stuffer->send_or_die;

        # carp('SendMail success');
        $job->completed();
        return 1;
    }
    catch {
        carp("Failed to SendMail: $_");
        $job->failed('Failed to SendMail');
        return;
    };

    return;
}

1;
