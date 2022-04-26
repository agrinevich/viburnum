package App::User::Say;

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
    my $msg_nick  = $o_params->{m} || q{default};

    my $dbh        = $app->dbh;
    my $root_dir   = $app->root_dir;
    my $site_host  = $app->config->{site}->{host};
    my $tpl_path   = $app->config->{templates}->{path_f};
    my $bread_path = $app->config->{data}->{bread_path};
    my $navi_path  = $app->config->{data}->{navi_path};
    # my $html_path   = $app->config->{data}->{html_path};

    my $page_id = 1; # we need it to read navi and bread files

    my $h_lang = Util::Langs::get_lang(
        dbh       => $dbh,
        lang_nick => $lang_nick,
    );

    my $h_marks = Util::Tree::get_marks(
        dbh     => $dbh,
        page_id => $page_id,
        lang_id => $h_lang->{lang_id},
    );

    my $tpl_name = sprintf 'say-%s%s.html', $msg_nick, $h_lang->{lang_suffix};

    my $file2check = $root_dir . $tpl_path . '/user/' . $tpl_name;
    if ( !-e $file2check ) {
        $tpl_name = sprintf 'say-default%s.html', $h_lang->{lang_suffix};
    }

    $h_marks->{page_main} = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/user',
        tpl_name => $tpl_name,
        h_vars   => {
            lang_nick => $h_lang->{lang_nick},
        },
    );

    # lang links, metatags and sitemap hrefs for this page
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

    $h_marks->{site_host} = $site_host;

    my $navi_fname = $page_id . q{-} . $h_lang->{lang_id} . '.html';
    my $navi       = Util::Files::read_file(
        file => $root_dir . $navi_path . q{/} . $navi_fname,
    );
    $h_marks->{navi} = $navi;

    my $bread_fname = $page_id . q{-} . $h_lang->{lang_id} . '.html';
    my $breadcrumbs = Util::Files::read_file(
        file => $root_dir . $bread_path . q{/} . $bread_fname,
    );
    $h_marks->{breadcrumbs} = $breadcrumbs;

    my $page = Util::Renderer::parse_html(
        dbh      => $dbh,
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => $h_marks,
    );

    return {
        body => $page,
    };
}

1;
