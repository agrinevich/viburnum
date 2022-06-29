package App::User::Cart::Enqusend;

use strict;
use warnings;

use Util::JobQueue;
use Util::Renderer;
use Util::Langs;
use Util::Users;
use Util::Notes;
use Util::Cart;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $ip        = $o_request->address() // q{};
    my $ua        = $o_request->user_agent() // q{};
    my $lang_nick = $o_params->{l} || q{};
    my $name      = $o_params->{name} || q{};
    my $email     = $o_params->{email} || q{};
    my $address   = $o_params->{address} || q{};

    #
    # TODO: is_ip_banned
    #

    my $site_host = $app->config->{site}->{host};

    my $h_sess = $app->session->data();
    if ( !$h_sess->{user_id} ) {
        return {
            url => $site_host . '/user/who?l=' . $lang_nick,
        };
    }

    # my $h_user = Util::Users::get_user(
    #     dbh => $app->dbh,
    #     id  => $h_sess->{user_id},
    # );

    my $h_lang = Util::Langs::get_lang(
        dbh       => $app->dbh,
        lang_nick => $lang_nick,
    );

    my $a_items = Util::Cart::get_goods(
        dbh     => $app->dbh,
        sess_id => $app->session->sess_id,
        lang_id => $h_lang->{lang_id},
    );
    #
    # TODO: move to _build_mail_body
    #
    my $total_sum = 0;
    my $goods     = q{};
    foreach my $h ( @{$a_items} ) {
        my $h_note = Util::Notes::get_note(
            dbh => $app->dbh,
            id  => $h->{id},
        );

        my $base_path = Util::Tree::page_path(
            dbh     => $app->dbh,
            page_id => $h_note->{page_id},
        );

        my $details_path = $h_lang->{lang_path} . $base_path;
        my $details_file = $h_note->{nick} . '.html';
        my $item_path    = $details_path . q{/} . $details_file;

        my $sum = $h->{price} * $h->{qty};
        $sum = sprintf '%.2f', $sum;
        $total_sum += $sum;

        $goods .= Util::Renderer::parse_html(
            root_dir => $app->root_dir,
            tpl_path => $app->config->{templates}->{path_f} . '/user',
            tpl_name => 'cart-amail-item.txt',
            h_vars   => {
                id        => $h->{id},
                qty       => $h->{qty},
                price     => $h->{price},
                name      => $h->{name},
                path      => $item_path,
                sum       => $sum,
                lang_nick => $h_lang->{lang_nick},
            },
        );
    }

    $total_sum = sprintf '%.2f', $total_sum;

    my $mail_body = _build_mail_body(
        # lang_isocode => $h_lang->{lang_isocode},
        # site_host => $app->config->{site}->{host},
        root_dir  => $app->root_dir,
        tpl_path  => $app->config->{templates}->{path_f},
        name      => $name,
        email     => $email,
        address   => $address,
        phone     => $h_sess->{phone},
        goods     => $goods,
        total_sum => $total_sum,
    );

    my $mail_subj = sprintf 'new order from %s', $h_sess->{phone};

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );
    if ( !$jqc ) {
        $app->logger->error('Enqumail aborted: failed to create jqc. ');
        return {
            url => $app->config->{site}->{host} . '/user/say?m=cartnotsent',
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
                rcp   => $app->config->{mail}->{recipient},
                snd   => $app->config->{mail}->{sender},
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
        $app->logger->error('Enqumail aborted: failed to create job. ');
        return {
            url => $app->config->{site}->{host} . '/user/say?m=cartnotsent',
        };
    }

    my $success = $jqc->insert($job);
    if ( !$success ) {
        $app->logger->error('Enqumail aborted: failed to insert job. ');
        return {
            url => $app->config->{site}->{host} . '/user/say?m=cartnotsent',
        };
    }

    _empty_cart(
        dbh     => $app->dbh,
        sess_id => $app->session->sess_id,
    );

    return {
        url => $app->config->{site}->{host} . '/user/say?m=cartsent',
    };
}

sub _empty_cart {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $sess_id = $args{sess_id};

    $dbh->do("DELETE FROM sess_cart WHERE sess_id = \"$sess_id\"");

    return;
}

sub _build_mail_body {
    my (%args) = @_;

    # my $lang_isocode = $args{lang_isocode};
    # my $site_host = $args{site_host};
    my $root_dir  = $args{root_dir};
    my $tpl_path  = $args{tpl_path};
    my $name      = $args{name};
    my $email     = $args{email};
    my $address   = $args{address};
    my $phone     = $args{phone};
    my $goods     = $args{goods};
    my $total_sum = $args{total_sum};

    my $result = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/user',
        tpl_name => 'cart-amail.txt',
        h_vars   => {
            # site_host => $site_host,
            name      => $name,
            email     => $email,
            address   => $address,
            phone     => $phone,
            goods     => $goods,
            total_sum => $total_sum,
        },
    );

    return $result;
}

1;
