package App::Worker::CreateNotes;

use strict;
use warnings;

use parent qw( TheSchwartz::Worker );
use TheSchwartz::Job;

use Const::Fast;
use Carp qw(croak carp);

use Util::DB;
use Util::Config;
use Util::Langs;
use Util::Renderer;
use Util::Files;
use Util::Notes;
use Util::Tree;

our $VERSION = '1.1';

const my $MAX_DEPTH_LEVEL => 9;

sub work {
    my ( $class, $job ) = @_;

    my %args = @{ $job->arg };

    my $root_dir  = $args{root_dir};
    my $conf_file = $args{conf_file};
    my $page_id   = $args{page_id};

    my $config = Util::Config::get_config(
        file => $root_dir . q{/} . $conf_file,
    );

    my $html_path  = $config->{data}->{html_path};
    my $bread_path = $config->{data}->{bread_path};
    my $navi_path  = $config->{data}->{navi_path};
    my $tpl_path   = $config->{templates}->{path_f};
    my $site_host  = $config->{site}->{host};

    my $dbh = Util::DB::get_dbh(
        db_name => $config->{mysql}->{db_name},
        db_user => $config->{mysql}->{user},
        db_pass => $config->{mysql}->{pass},
    );

    my $base_path = Util::Tree::page_path(
        dbh     => $dbh,
        page_id => $page_id,
    );

    my $h_page = Util::Tree::get_page(
        dbh     => $dbh,
        page_id => $page_id,
    );

    my $mode_config = Util::Config::get_mode_config(
        root_dir  => $root_dir,
        page_id   => $page_id,
        html_path => $html_path,
        base_path => $base_path,
        mode_name => 'note',
    );

    my $a_langs = Util::Langs::get_langs( dbh => $dbh );

    foreach my $h_lang ( @{$a_langs} ) {
        my $notes_dir = $root_dir . $html_path . $h_lang->{lang_path} . $base_path;
        if ( !-d $notes_dir ) {
            Util::Files::make_path( path => $notes_dir );
        }
    }

    my $skin      = $mode_config->{note}->{skin};
    my $npp       = $mode_config->{note}->{npp} || 1;
    my $order_by  = $mode_config->{note}->{order_by};
    my $order_how = $mode_config->{note}->{order_how};
    my $em_key    = $mode_config->{note}->{em_key};
    my $is_public = $mode_config->{note}->{is_public};
    # my $em_rcp    = $mode_config->{note}->{em_rcp};
    # my $em_snd    = $mode_config->{note}->{em_snd};
    # my $ttl_days    = $mode_config->{note}->{ttl_days};

    my $total_qty = Util::Notes::get_qty(
        dbh     => $dbh,
        page_id => $page_id,
        # is_ext  => 0,
    );
    my $p_qty  = int( $total_qty / $npp ) + 1;
    my $p_last = $p_qty - 1;

    foreach my $p ( 0 .. $p_last ) {
        my $offset = $p * $npp;

        foreach my $h_lang ( @{$a_langs} ) {
            gen_list_page(
                dbh         => $dbh,
                root_dir    => $root_dir,
                site_host   => $site_host,
                html_path   => $html_path,
                base_path   => $base_path,
                bread_path  => $bread_path,
                navi_path   => $navi_path,
                tpl_path    => $tpl_path,
                a_langs     => $a_langs,
                lang_path   => $h_lang->{lang_path},
                lang_id     => $h_lang->{lang_id},
                lang_suffix => $h_lang->{lang_suffix},
                page_id     => $page_id,
                page_name   => $h_page->{name},
                order_by    => $order_by,
                order_how   => $order_how,
                em_key      => $em_key,
                offset      => $offset,
                npp         => $npp,
                skin        => $skin,
                total_qty   => $total_qty,
                p           => $p,
                is_public   => $is_public,
            );
        }

    }

    carp('generated: notes pages');

    $job->completed();
    return;
}

sub gen_list_page {
    my (%args) = @_;

    my $dbh         = $args{dbh};
    my $root_dir    = $args{root_dir};
    my $site_host   = $args{site_host};
    my $html_path   = $args{html_path};
    my $base_path   = $args{base_path};
    my $bread_path  = $args{bread_path};
    my $navi_path   = $args{navi_path};
    my $tpl_path    = $args{tpl_path};
    my $a_langs     = $args{a_langs};
    my $lang_path   = $args{lang_path};
    my $lang_id     = $args{lang_id};
    my $lang_suffix = $args{lang_suffix};
    my $page_id     = $args{page_id};
    my $page_name   = $args{page_name};
    my $order_by    = $args{order_by};
    my $order_how   = $args{order_how};
    my $em_key      = $args{em_key};
    my $offset      = $args{offset};
    my $npp         = $args{npp};
    my $skin        = $args{skin};
    my $total_qty   = $args{total_qty};
    my $p           = $args{p};
    my $is_public   = $args{is_public};

    my $suffix = $p ? $p : q{};

    # lang links, metatags for this page
    my $h_langhref = Util::Langs::build_hrefs(
        a_langs   => $a_langs,
        base_path => $base_path . "/index$suffix.html",
        root_dir  => $root_dir,
        site_host => $site_host,
        tpl_path  => $tpl_path,
    );

    my $h_marks = Util::Tree::get_marks(
        dbh     => $dbh,
        page_id => $page_id,
        lang_id => $lang_id,
    );

    $h_marks->{lang_metatags} = $h_langhref->{metatags};
    $h_marks->{lang_links}    = $h_langhref->{links};
    $h_marks->{site_host}     = $site_host;

    my $mnavi_fname = 'm-' . $page_id . q{-} . $lang_id . '.html';
    my $mnavi       = Util::Files::read_file(
        file => $root_dir . $navi_path . q{/} . $mnavi_fname,
    );
    $h_marks->{mnavi} = $mnavi;

    my $dnavi_fname = 'd-' . $page_id . q{-} . $lang_id . '.html';
    my $dnavi       = Util::Files::read_file(
        file => $root_dir . $navi_path . q{/} . $dnavi_fname,
    );
    $h_marks->{dnavi} = $dnavi;

    my $bread_fname = $page_id . q{-} . $lang_id . '.html';
    my $breadcrumbs = Util::Files::read_file(
        file => $root_dir . $bread_path . q{/} . $bread_fname,
    );
    $h_marks->{breadcrumbs} = $breadcrumbs;

    my $list   = q{};
    my $paging = q{};
    if ($is_public) {
        my $a_notes = Util::Notes::list(
            dbh       => $dbh,
            page_id   => $page_id,
            lang_id   => $lang_id,
            order_by  => $order_by,
            order_how => $order_how,
            offset    => $offset,
            npp       => $npp,
            # is_ext    => 0,
        );

        foreach my $h ( @{$a_notes} ) {
            my $details_path = $lang_path . $base_path;
            my $details_file = $h->{nick} . '.html';

            my $a_images = Util::Notes::images(
                note_id => $h->{id},
                dbh     => $dbh,
            );
            my $h_first_img = $a_images->[0];

            $list .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . q{/} . $skin,
                tpl_name => 'list-item.html',
                h_vars   => {
                    # id          => $h->{id},
                    # name        => $h->{name},
                    # nick        => $h->{nick},
                    # add_dt      => $h->{add_dt},
                    # price       => $h->{price},
                    %{$h},
                    img_path_sm => $h_first_img->{path_sm},
                    path        => $details_path . q{/} . $details_file,
                },
            );

            gen_details_page(
                dbh          => $dbh,
                root_dir     => $root_dir,
                tpl_path     => $tpl_path,
                skin         => $skin,
                tpl_name     => 'details.html',
                site_host    => $site_host,
                html_path    => $html_path,
                base_path    => $base_path,
                details_path => $details_path,
                details_file => $details_file,
                a_images     => $a_images,
                a_langs      => $a_langs,
                h_note       => $h,
                h_marks      => { %{$h_marks} },
            );
        }

        $paging = Util::Renderer::build_paging(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            qty      => $total_qty,
            npp      => $npp,
            p        => $p,
            path     => $lang_path . $base_path,
        );
    }

    # create lang version tpl from default if not found
    my $skin_tpl_dir = $root_dir . $tpl_path . q{/} . $skin;
    my $mailform_tpl = $skin_tpl_dir . '/email-form' . $lang_suffix . '.html';
    if ( !-e $mailform_tpl ) {
        Util::Files::copy_file(
            src => $skin_tpl_dir . '/email-form.html',
            dst => $mailform_tpl,
        );
    }

    my $email_form = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $skin,
        tpl_name => 'email-form' . $lang_suffix . '.html',
        h_vars   => {
            lang_id => $lang_id,
            page_id => $page_id,
            em_key  => $em_key,
        },
    );

    $h_marks->{page_main} = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $skin,
        tpl_name => 'list.html',
        h_vars   => {
            page_name  => $page_name,
            email_form => $email_form,
            list       => $list,
            paging     => $paging,
        },
    );

    Util::Renderer::write_html(
        $h_marks,
        {
            dbh       => $dbh,
            root_dir  => $root_dir,
            html_path => $html_path,
            tpl_path  => $tpl_path,
            tpl_file  => 'layout.html',
            out_path  => $lang_path . $base_path,
            out_file  => "index$suffix.html",
        }
    );

    return;
}

sub gen_details_page {
    my (%args) = @_;

    my $dbh          = $args{dbh};
    my $root_dir     = $args{root_dir};
    my $tpl_path     = $args{tpl_path};
    my $skin         = $args{skin};
    my $tpl_name     = $args{tpl_name};
    my $site_host    = $args{site_host};
    my $html_path    = $args{html_path};
    my $base_path    = $args{base_path};
    my $details_path = $args{details_path};
    my $details_file = $args{details_file};
    my $a_images     = $args{a_images};
    my $a_langs      = $args{a_langs};
    my $h_note       = $args{h_note};
    my $h_marks      = $args{h_marks};

    my $img_list_sm = q{};
    my $img_list_la = q{};
    foreach my $h ( @{$a_images} ) {
        $h->{name} = $h_note->{p_title};

        $img_list_sm .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . q{/} . $skin,
            tpl_name => 'details-img-sm.html',
            h_vars   => $h,
        );

        $img_list_la .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . q{/} . $skin,
            tpl_name => 'details-img-la.html',
            h_vars   => $h,
        );
    }
    $h_note->{img_list_sm} = $img_list_sm;
    $h_note->{img_list_la} = $img_list_la;

    $h_note->{descr} =~ s/\n/<br>/g;

    $h_marks->{page_main} = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . q{/} . $skin,
        tpl_name => $tpl_name,
        h_vars   => $h_note,
    );
    $h_marks->{page_title} = $h_note->{p_title};
    $h_marks->{page_descr} = $h_note->{p_descr};
    # lang links, metatags for this page
    my $h_langhref = Util::Langs::build_hrefs(
        a_langs   => $a_langs,
        base_path => $base_path . q{/} . $details_file,
        root_dir  => $root_dir,
        site_host => $site_host,
        tpl_path  => $tpl_path,
    );
    $h_marks->{lang_metatags} = $h_langhref->{metatags};
    $h_marks->{lang_links}    = $h_langhref->{links};

    Util::Renderer::write_html(
        $h_marks,
        {
            dbh       => $dbh,
            root_dir  => $root_dir,
            html_path => $html_path,
            tpl_path  => $tpl_path,
            tpl_file  => 'layout.html',
            out_path  => $details_path,
            out_file  => $details_file,
        }
    );

    return;
}

1;
