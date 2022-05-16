package App::Admin::Note;

use strict;
use warnings;

use English qw(-no_match_vars);

use Util::Renderer;
use Util::Langs;
use Util::Tree;
use Util::Notes;
use Util::Config;
use Util::Files;
use Util::Crypto;

our $VERSION = '1.1';

#
# 'note' is builtin plugin
#

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $page_id  = $o_params->{page_id} || 0;
    my $p        = $o_params->{p} || 0;

    my $root_dir    = $app->root_dir;
    my $tpl_path    = $app->config->{templates}->{path};
    my $tpl_path_f  = $app->config->{templates}->{path_f};
    my $html_path   = $app->config->{data}->{html_path};
    my $site_domain = $app->config->{site}->{domain};

    my $base_path = Util::Tree::page_path(
        dbh     => $app->dbh,
        page_id => $page_id,
    );

    my $h_page = Util::Tree::get_page(
        dbh     => $app->dbh,
        page_id => $page_id,
    );

    my $lang_id   = 1;  # always show list in primary language
    my $lang_path = q{};

    my $o_mode_config = Util::Config::get_mode_config(
        root_dir   => $root_dir,
        page_id    => $page_id,
        html_path  => $html_path,
        base_path  => $base_path,
        mode_name  => 'note',
        replace_cb => sub {
            my (%cb_args) = @_;

            $cb_args{site_domain} = $site_domain;

            config_autoreplace(%cb_args);

            return;
        },
    );

    my $config_html = Util::Config::build_config_html(
        root_dir  => $root_dir,
        tpl_path  => $tpl_path,
        html_path => $html_path,
        mode_name => 'note',
        o_config  => $o_mode_config,
    );

    #
    # sync templates
    #
    my $a_tpl_dir_def = $root_dir . $tpl_path . '/note';
    my $f_tpl_dir_def = $root_dir . $tpl_path_f . q{/note-default};
    my $skin_tpl_path = $tpl_path_f . q{/} . $o_mode_config->{note}->{skin};
    my $skin_tpl_dir  = $root_dir . $skin_tpl_path;
    if ( !-d $skin_tpl_dir ) {
        Util::Files::make_path( path => $skin_tpl_dir );
    }
    # copy missing admin templates
    my $a_adm_tpls = Util::Files::get_files(
        dir        => $a_tpl_dir_def,
        files_only => 1,
    );
    foreach my $h_tpl ( @{$a_adm_tpls} ) {
        my $dst_file = $skin_tpl_dir . q{/a-} . $h_tpl->{name};
        if ( !-e $dst_file ) {
            Util::Files::copy_file(
                src => $a_tpl_dir_def . q{/} . $h_tpl->{name},
                dst => $dst_file,
            );
        }
    }
    # copy missing front-end templates
    my $a_front_tpls = Util::Files::get_files(
        dir        => $f_tpl_dir_def,
        files_only => 1,
    );
    foreach my $h_tpl ( @{$a_front_tpls} ) {
        my $dst_file = $skin_tpl_dir . q{/} . $h_tpl->{name};
        if ( !-e $dst_file ) {
            Util::Files::copy_file(
                src => $f_tpl_dir_def . q{/} . $h_tpl->{name},
                dst => $dst_file,
            );
        }
    }

    my $total_qty = Util::Notes::get_qty(
        dbh     => $app->dbh,
        page_id => $page_id,
    );
    my $npp    = $o_mode_config->{note}->{npp} || 1;
    my $offset = $p * $npp;

    my $a_notes = Util::Notes::list(
        dbh       => $app->dbh,
        page_id   => $page_id,
        lang_id   => $lang_id,
        order_by  => $o_mode_config->{note}->{order_by},
        order_how => $o_mode_config->{note}->{order_how},
        offset    => $offset,
        npp       => $npp,
    );

    my $list = q{};
    foreach my $h ( @{$a_notes} ) {
        my $a_images = Util::Notes::images(
            note_id => $h->{id},
            dbh     => $app->dbh,
        );
        my $h_first_img = $a_images->[0];

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $skin_tpl_path,
            tpl_name => 'a-list-item.html',
            h_vars   => {
                id          => $h->{id},
                name        => $h->{name},
                nick        => $h->{nick},
                add_dt      => $h->{add_dt},
                price       => $h->{price},
                img_path_sm => $h_first_img->{path_sm},
            },
        );
    }

    my $paging = Util::Renderer::build_paging(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        qty      => $total_qty,
        npp      => $npp,
        p        => $p,
        path     => '/admin/note?page_id=' . $page_id . '&p=',
    );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_name => 'a-list.html',
        h_vars   => {
            page_id   => $page_id,
            page_name => $h_page->{name},
            list      => $list,
            config    => $config_html,
            paging    => $paging,
            qty       => $total_qty,
        },
    );

    my $page = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $body,
        },
    );

    return {
        body => $page,
    };
}

sub config_autoreplace {
    my (%args) = @_;

    my $o_config    = $args{o_config};
    my $mode_name   = $args{mode_name};
    my $page_id     = $args{page_id};
    my $site_domain = $args{site_domain};

    # auto-replace default skin
    if ( $o_config->{$mode_name}->{skin} eq 'AUTOREPLACE' ) {
        $o_config->{$mode_name}->{skin} = $mode_name . '-skin-' . $page_id;
    }

    # auto-replace default em_snd
    if ( $o_config->{$mode_name}->{em_snd} eq 'AUTOREPLACE' ) {
        $o_config->{$mode_name}->{em_snd} = 'robot' . $page_id . q{@} . $site_domain;
    }

    # auto-replace default em_rcp
    if ( $o_config->{$mode_name}->{em_rcp} eq 'AUTOREPLACE' ) {
        $o_config->{$mode_name}->{em_rcp} = 'info@' . $site_domain;
    }

    # auto-replace default em_key
    if ( $o_config->{$mode_name}->{em_key} eq 'AUTOREPLACE' ) {
        my $email_form_key = Util::Crypto::get_sha1_hex(
            str => rand . $PID . {} . time,
        );
        $o_config->{$mode_name}->{em_key} = $email_form_key;
    }

    return;
}

1;
