package App::User::Enqumail;

use strict;
use warnings;

use Util::JobQueue;
use Util::Renderer;
use Util::Tree;
use Util::Config;
use Util::Langs;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params        = $o_request->parameters();
    my $ip              = $o_request->address() // q{};
    my $ua              = $o_request->user_agent() // q{};
    my $page_id         = $o_params->{page_id} || 0;
    my $lang_id         = $o_params->{lang_id} || 0;
    my $em_key_in       = $o_params->{em_key} || q{};
    my $botfield        = $o_params->{secret} || q{};
    my $ref_url         = $o_params->{whoareyou} || q{};
    my $browser_lang    = $o_params->{doyouspeak} || q{};
    my $cookies_enabled = $o_params->{doyoulikecookies} || q{};

    my $err_report_tpl
        = 'ip = %s, ua = %s, lang_id = %s, honeypot = %s, ref = %s, browser_lang = %s, cookies = %s';
    my $report = sprintf $err_report_tpl, $ip, $ua, $lang_id, $botfield, $ref_url, $browser_lang,
        $cookies_enabled;

    # 'secret' must be empty
    if ($botfield) {
        $app->logger->error( 'Enqumail aborted: wrong secret. ' . $report );
        return { url => $app->config->{site}->{host} . '/user/say?m=mailerror' };
    }

    # 'ref_url' must NOT be empty
    if ( !$ref_url ) {
        $app->logger->error( 'Enqumail aborted: empty referer. ' . $report );
        return { url => $app->config->{site}->{host} . '/user/say?m=mailerror' };
    }

    # 'cookies_enabled' must be 'true'
    if ( $cookies_enabled ne 'true' ) {
        $app->logger->error( 'Enqumail aborted: cookies disabled. ' . $report );
        return { url => $app->config->{site}->{host} . '/user/say?m=mailerror' };
    }

    #
    # TODO: is_ip_banned
    #

    my $base_path = Util::Tree::page_path(
        dbh     => $app->dbh,
        page_id => $page_id,
    );

    my $h_lang = Util::Langs::get_lang(
        dbh     => $app->dbh,
        lang_id => $lang_id,
    );

    my $mode_config = Util::Config::get_mode_config(
        root_dir  => $app->root_dir,
        html_path => $app->config->{data}->{html_path},
        base_path => $base_path,
        page_id   => $page_id,
        mode_name => 'note',
    );
    my $em_key   = $mode_config->{note}->{em_key};
    my $em_rcp   = $mode_config->{note}->{em_rcp};
    my $em_snd   = $mode_config->{note}->{em_snd};
    my $ttl_days = $mode_config->{note}->{ttl_days};

    if ( $em_key_in ne $em_key ) {
        $app->logger->error( 'Enqumail aborted: wrong em_key_in. ' . $report );
        return {
            url => $app->config->{site}->{host} . '/user/say?m=mailerror',
        };
    }

    _delete_expired(
        dbh      => $app->dbh,
        ttl_days => $ttl_days,
        page_id  => $page_id,
    );

    my $mail_body = _build_mail_body(
        root_dir     => $app->root_dir,
        tpl_path     => $app->config->{templates}->{path},
        site_host    => $app->config->{site}->{host},
        o_params     => $o_params,
        lang_isocode => $h_lang->{lang_isocode},
    );

    my $mail_subj = sprintf 'mail: %s - %s', $em_snd, $em_rcp;

    _store_mail(
        dbh       => $app->dbh,
        page_id   => $page_id,
        lang_id   => $lang_id,
        mail_body => $mail_body,
        mail_subj => $mail_subj,
        em_rcp    => $em_rcp,
        em_snd    => $em_snd,
        ip        => $ip,
    );

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );
    if ( !$jqc ) {
        $app->logger->error( 'Enqumail aborted: failed to create jqc. ' . $report );
        return {
            url => $app->config->{site}->{host} . '/user/say?m=mailerror',
        };
    }

    # TODO: MD5 of args
    my $uniqkey;

    my $job = Util::JobQueue::new_job(
        {
            uniqkey  => $uniqkey,
            funcname => 'App::Worker::SendMail',
            args     => {
                body  => $mail_body,
                subj  => $mail_subj,
                rcp   => $em_rcp,
                snd   => $em_snd,
                host  => $app->config->{mail}->{host},
                port  => $app->config->{mail}->{port},
                ssl   => $app->config->{mail}->{ssl},
                user  => $app->config->{mail}->{user},
                pass  => $app->config->{mail}->{pass},
                debug => $app->config->{mail}->{debug},
            },
        }
    );
    if ( !$job ) {
        $app->logger->error( 'Enqumail aborted: failed to create job. ' . $report );
        return {
            url => $app->config->{site}->{host} . '/user/say?m=mailerror',
        };
    }

    my $success = $jqc->insert($job);
    if ( !$success ) {
        $app->logger->error( 'Enqumail aborted: failed to insert job. ' . $report );
        return {
            url => $app->config->{site}->{host} . '/user/say?m=mailerror',
        };
    }

    return {
        url => $app->config->{site}->{host} . '/user/say?m=mailsent',
    };
}

sub _delete_expired {
    my (%args) = @_;

    my $dbh      = $args{dbh};
    my $page_id  = $args{page_id};
    my $ttl_days = $args{ttl_days};

    return if !$ttl_days;

    my @ids = ();

    my $sel = <<'EOF';
        SELECT id
        FROM notes
        WHERE page_id = ?
        AND is_ext = 1
        AND TO_DAYS(NOW()) - TO_DAYS(add_dt) > ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $page_id, $ttl_days );
    while ( my ($id) = $sth->fetchrow_array() ) {
        push @ids, $id;
    }
    $sth->finish();

    foreach my $note_id (@ids) {
        $dbh->do("DELETE FROM notes_versions WHERE note_id = $note_id");
        $dbh->do("DELETE FROM notes_images WHERE note_id = $note_id");
        $dbh->do("DELETE FROM notes WHERE id = $note_id");
    }

    return;
}

sub _store_mail {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $page_id   = $args{page_id};
    my $lang_id   = $args{lang_id};  # why ?
    my $mail_body = $args{mail_body};
    my $mail_subj = $args{mail_subj};
    my $em_rcp    = $args{em_rcp};
    my $em_snd    = $args{em_snd};
    my $ip        = $args{ip};

    $dbh->do("INSERT INTO notes (page_id, is_ext, ip) VALUES ($page_id, 1, \"$ip\")");

    my $sel = 'SELECT LAST_INSERT_ID()';
    my $sth = $dbh->prepare($sel);
    $sth->execute;
    my ($note_id) = $sth->fetchrow_array();
    $sth->finish;

    my $a_langs = Util::Langs::get_langs( dbh => $dbh );
    my $ins2    = <<'EOF2';
        INSERT INTO notes_versions
        (note_id, lang_id, name, descr)
        VALUES
        (?, ?, ?, ?)
EOF2
    my $sth2 = $dbh->prepare($ins2);

    foreach my $h_lang ( @{$a_langs} ) {
        $sth2->execute( $note_id, $h_lang->{lang_id}, $mail_subj, $mail_body );
    }

    return;
}

sub _build_mail_body {
    my (%args) = @_;

    my $root_dir     = $args{root_dir};
    my $tpl_path     = $args{tpl_path};
    my $site_host    = $args{site_host};
    my $o_params     = $args{o_params};
    my $lang_isocode = $args{lang_isocode};

    my $result = q{};

    foreach my $param ( $o_params->keys() ) {
        $result .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/note',
            tpl_name => 'mail-item.txt',
            h_vars   => {
                name  => $param,
                value => $o_params->{$param},
            },
        );
    }

    $result .= Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/note',
        tpl_name => 'mail-item.txt',
        h_vars   => {
            name  => 'lang_isocode',
            value => $lang_isocode,
        },
    );

    return $result;
}

1;
