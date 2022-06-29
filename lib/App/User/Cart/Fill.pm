package App::User::Cart::Fill;

use strict;
use warnings;

use URI::Escape;

use Util::Renderer;
use Util::Langs;
use Util::Files;
use Util::Users;
use Util::Notes;
use Util::Cart;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} // q{};

    my $dbh        = $app->dbh;
    my $root_dir   = $app->root_dir;
    my $site_host  = $app->config->{site}->{host};
    my $tpl_path   = $app->config->{templates}->{path_f};
    my $bread_path = $app->config->{data}->{bread_path};
    my $navi_path  = $app->config->{data}->{navi_path};
    my $html_path  = $app->config->{data}->{html_path};

    my $h_sess = $app->session->data();
    if ( !$h_sess->{user_id} ) {
        my $ret  = $site_host . '/user/cart/fill?l=' . $lang_nick;
        my $rete = uri_escape($ret);
        return {
            url => $site_host . '/user/who?l=' . $lang_nick . '&ret=' . $rete,
        };
    }

    my $h_user = Util::Users::get_user(
        dbh => $app->dbh,
        id  => $h_sess->{user_id},
    );

    my $page_path = q{}; # we are using root user layout

    my $h_lang = Util::Langs::get_lang(
        dbh       => $dbh,
        lang_nick => $lang_nick,
    );

    my $a_items = Util::Cart::get_goods(
        dbh     => $dbh,
        sess_id => $app->session->sess_id,
        lang_id => $h_lang->{lang_id},
    );
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
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/user',
            tpl_name => 'cart-item2.html',
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

    if ( !$goods ) {
        return {
            url => $site_host . '/user/cart?l=' . $lang_nick,
        };
    }

    $total_sum = sprintf '%.2f', $total_sum;

    my $tpl_name = sprintf 'cart-fill%s.html', $h_lang->{lang_suffix};
    my $tpl_file = $root_dir . $tpl_path . '/user/' . $tpl_name;
    if ( !-e $tpl_file ) {
        my $tpl_file_primary = $root_dir . $tpl_path . '/user/cart-fill.html';
        Util::Files::copy_file(
            src => $tpl_file_primary,
            dst => $tpl_file,
        );
    }

    my $h_marks = {};

    $h_marks->{page_title} = 'Cart';
    $h_marks->{page_main}  = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/user',
        tpl_name => $tpl_name,
        h_vars   => {
            lang_nick => $h_lang->{lang_nick},
            phone     => $h_sess->{phone},
            name      => $h_user->{name},
            email     => $h_user->{email},
            address   => $h_user->{address},
            goods     => $goods,
            total_sum => $total_sum,
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
        dbh      => $dbh,
        root_dir => $root_dir,
        tpl_path => $html_path . $h_lang->{lang_path} . $page_path,
        tpl_name => 'layout-user.html',
        h_vars   => $h_marks,
    );

    return {
        body => $page,
    };
}

1;
