package App::User::Who;

use strict;
use warnings;

use Util::Renderer;
use Util::Langs;
use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} // q{};
    my $ret_url   = $o_params->{ret} // q{};

    my $dbh        = $app->dbh;
    my $root_dir   = $app->root_dir;
    my $site_host  = $app->config->{site}->{host};
    my $tpl_path   = $app->config->{templates}->{path_f};
    my $bread_path = $app->config->{data}->{bread_path};
    my $navi_path  = $app->config->{data}->{navi_path};
    my $html_path  = $app->config->{data}->{html_path};

    # check if session has pending code
    my $h_sess = $app->session->data();
    if ( $h_sess->{otp} ) {
        return {
            url => $app->config->{site}->{host} . '/user/who/pending?phone=' . $h_sess->{phone},
        };
    }

    my $page_path = q{}; # root layout

    my $h_lang = Util::Langs::get_lang(
        dbh       => $dbh,
        lang_nick => $lang_nick,
    );

    my $tpl_name = sprintf 'who%s.html', $h_lang->{lang_suffix};
    my $tpl_file = $root_dir . $tpl_path . '/user/' . $tpl_name;
    if ( !-e $tpl_file ) {
        my $tpl_file_primary = $root_dir . $tpl_path . '/user/who.html';
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
            ret_url   => $ret_url,
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

1;
