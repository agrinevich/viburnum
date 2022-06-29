package App::User::Cart;

use strict;
use warnings;

use Const::Fast;

use Util::Renderer;
use Util::Files;
use Util::Langs;
use Util::Tree;
use Util::Notes;
use Util::Cart;

our $VERSION = '1.1';

const my $_MAX_QTY => 100;

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} // q{};

    my $sess       = $app->session;
    my $dbh        = $app->dbh;
    my $root_dir   = $app->root_dir;
    my $site_host  = $app->config->{site}->{host};
    my $tpl_path   = $app->config->{templates}->{path_f};
    my $bread_path = $app->config->{data}->{bread_path};
    my $navi_path  = $app->config->{data}->{navi_path};
    my $html_path  = $app->config->{data}->{html_path};

    my $page_path = q{};        # root layout
    my $a_qty     = _qty_list();

    my $h_lang = Util::Langs::get_lang(
        dbh       => $dbh,
        lang_nick => $lang_nick,
    );

    my $a_items = Util::Cart::get_goods(
        dbh     => $dbh,
        sess_id => $sess->sess_id,
        lang_id => $h_lang->{lang_id},
    );
    my $total_sum = 0;
    my $list      = q{};
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

        my $qty_options = Util::Renderer::build_options(
            items    => $a_qty,
            id_sel   => $h->{qty},
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/user',
            tpl_file => 'cart-qty-option.html',
        );

        my $sum = $h->{price} * $h->{qty};
        $sum = sprintf '%.2f', $sum;
        $total_sum += $sum;

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/user',
            tpl_name => 'cart-item.html',
            h_vars   => {
                id          => $h->{id},
                qty         => $h->{qty},
                price       => $h->{price},
                name        => $h->{name},
                path        => $item_path,
                sum         => $sum,
                qty_options => $qty_options,
                lang_nick   => $h_lang->{lang_nick},
            },
        );
    }

    my $tpl_name = q{};
    if ($list) {
        $total_sum = sprintf '%.2f', $total_sum;

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/user',
            tpl_name => 'cart-total.html',
            h_vars   => {
                total_sum => $total_sum,
            },
        );

        $tpl_name = sprintf 'cart%s.html', $h_lang->{lang_suffix};
        my $tpl_file = $root_dir . $tpl_path . '/user/' . $tpl_name;

        if ( !-e $tpl_file ) {
            # create tpl from default tpl
            my $tpl_file_primary = $root_dir . $tpl_path . '/user/cart.html';
            Util::Files::copy_file(
                src => $tpl_file_primary,
                dst => $tpl_file,
            );
        }
    }
    else {
        $tpl_name = sprintf 'cart-empty%s.html', $h_lang->{lang_suffix};
        my $tpl_file = $root_dir . $tpl_path . '/user/' . $tpl_name;

        if ( !-e $tpl_file ) {
            # create tpl from default tpl
            my $tpl_file_primary = $root_dir . $tpl_path . '/user/cart-empty.html';
            Util::Files::copy_file(
                src => $tpl_file_primary,
                dst => $tpl_file,
            );
        }
    }

    my $h_marks = {};

    $h_marks->{page_title} = 'Cart';
    $h_marks->{page_main}  = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/user',
        tpl_name => $tpl_name,
        h_vars   => {
            lang_nick => $h_lang->{lang_nick},
            list      => $list,
        },
    );

    # lang links for this page
    my $a_langs    = Util::Langs::get_langs( dbh => $dbh );
    my $h_langhref = Util::Langs::build_hrefs(
        a_langs       => $a_langs,
        lang_path_cur => $h_lang->{lang_path},
        base_path     => q{},
        app_path      => $o_request->path_info(),
        root_dir      => $root_dir,
        site_host     => $site_host,
        tpl_path      => $tpl_path,
    );
    $h_marks->{lang_metatags} = $h_langhref->{metatags};
    $h_marks->{lang_links}    = $h_langhref->{links};

    my $page = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $html_path . $h_lang->{lang_path} . $page_path,
        tpl_name => 'layout-user.html',
        h_vars   => $h_marks,
    );

    return {
        body => $page,
    };
}

sub _qty_list {
    my @result = ();

    foreach my $i ( 1 .. $_MAX_QTY ) {
        push @result, {
            id   => $i,
            name => $i,
        };
    }

    return \@result;
}

1;
