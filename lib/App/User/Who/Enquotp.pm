package App::User::Who::Enquotp;

use strict;
use warnings;

use Util::JobQueue;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} || q{};
    my $ret_url   = $o_params->{ret} || q{};
    my $phone     = $o_params->{phone} || q{};

    #
    # TODO: is_ip_banned (in User app?)
    #

    #
    # TODO: validate and restrict to UA phones
    #
    $phone =~ s/\D//g;

    # he could start auth on another device
    # check if phone has pending code
    if ( $app->session->is_phone_pending($phone) ) {
        return {
            url => $app->config->{site}->{host} . '/user/who/pending?phone=' . $phone,
        };
    }

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );
    if ( !$jqc ) {
        $app->logger->error('Enquotp aborted: failed to create jqc. ');
        return {
            url => $app->config->{site}->{host} . '/user/say?m=enquotperror',
        };
    }

    # TODO: MD5 of args
    my $uniqkey;

    my $job = Util::JobQueue::new_job(
        {
            uniqkey  => $uniqkey,
            funcname => 'App::Worker::SendOtp',
            args     => {
                root_dir  => $app->root_dir,
                conf_file => $app->conf_file,
                lang_nick => $lang_nick,
                phone     => $phone,
                sess_id   => $app->session->sess_id(),
            },
        }
    );
    if ( !$job ) {
        $app->logger->error('Enquotp aborted: failed to create job. ');
        return {
            url => $app->config->{site}->{host} . '/user/say?m=enquotperror',
        };
    }

    my $success = $jqc->insert($job);
    if ( !$success ) {
        $app->logger->error('Enquotp aborted: failed to insert job. ');
        return {
            url => $app->config->{site}->{host} . '/user/say?m=enquotperror',
        };
    }

    return {
        url => $app->config->{site}->{host} . '/user/who/pending?phone=' . $phone,
    };
}

1;
