package App::User::Cart;

use strict;
use warnings;

use Util::Renderer;
use Util::Tree;
use Util::Files;
use Util::Langs;

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

    my $page_path = q{}; # we are using root user layout

    my $h_lang = Util::Langs::get_lang(
        dbh       => $dbh,
        lang_nick => $lang_nick,
    );

    my $list = q{my goods here.};

    my $tpl_name = sprintf 'cart%s.html', $h_lang->{lang_suffix};
    my $tpl_file = $root_dir . $tpl_path . '/user/' . $tpl_name;

    if ( !-e $tpl_file ) {
        # create tpl from default tpl
        my $tpl_file_primary = $root_dir . $tpl_path . '/user/cart.html';
        Util::Files::copy_file(
            src => $tpl_file_primary,
            dst => $tpl_file,
        );
    }

    my $h_marks = {};

    $h_marks->{page_main} = Util::Renderer::parse_html(
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
        a_langs   => $a_langs,
        base_path => q{},
        app_path  => $o_request->path_info(),
        root_dir  => $root_dir,
        site_host => $site_host,
        tpl_path  => $tpl_path,
    );
    $h_marks->{lang_metatags} = $h_langhref->{metatags};
    $h_marks->{lang_links}    = $h_langhref->{links};

    my $page = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $html_path . $page_path,
        tpl_name => 'layout-user.html',
        h_vars   => $h_marks,
    );

    return {
        body => $page,
    };
}

1;
