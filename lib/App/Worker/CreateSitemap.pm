package App::Worker::CreateSitemap;

use strict;
use warnings;

use parent qw( TheSchwartz::Worker );
use TheSchwartz::Job;

use Const::Fast;
use Carp qw(croak carp);
use POSIX ();
use POSIX qw(strftime);

use Util::DB;
use Util::Config;
use Util::Langs;
use Util::Renderer;
use Util::Files;
use Util::Tree;

our $VERSION = '1.1';

const my $MAX_DEPTH_LEVEL => 9;

sub work {
    my ( $class, $job ) = @_;

    my %args = @{ $job->arg };

    my $root_dir  = $args{root_dir};
    my $log_file  = $args{log_file};
    my $conf_file = $args{conf_file};

    my $config = Util::Config::get_config(
        file => $root_dir . q{/} . $conf_file,
    );

    my $dbh = Util::DB::get_dbh(
        db_name => $config->{mysql}->{db_name},
        db_user => $config->{mysql}->{user},
        db_pass => $config->{mysql}->{pass},
    );

    my $a_langs  = Util::Langs::get_langs( dbh => $dbh );
    my $cur_date = strftime( '%Y-%m-%d', localtime );
    my $a_map    = [];

    # collect array to build sitemap
    # create dirs
    # create breadcrumbs files
    # create navi files
    go_tree(
        dbh         => $dbh,
        config      => $config,
        root_dir    => $root_dir,
        cur_date    => $cur_date,
        parent_id   => 0,
        parent_path => q{},
        level       => 0,
        a_langs     => [ @{$a_langs} ],
        a_map       => $a_map,
    );

    # build sitemap.xml from collected array
    my $tpl_path  = $config->{templates}->{path_f};
    my $map_items = join q{}, @{$a_map};
    Util::Renderer::write_html(
        {
            items => $map_items,
        },
        {
            root_dir  => $root_dir,
            html_path => $config->{data}->{html_path},
            tpl_path  => $tpl_path . '/cat',
            tpl_file  => q{sitemap.xml},
            out_path  => q{},
            out_file  => q{sitemap.xml},
        }
    );

    carp(q{done: dirs, sitemap, breadcrumbs and navi files});
    $job->completed();
    return;
}

sub go_tree {
    my (%args) = @_;

    my $dbh      = $args{dbh};
    my $config   = $args{config};
    my $root_dir = $args{root_dir};
    my $cur_date = $args{cur_date};

    my $parent_id   = $args{parent_id}   // 0;
    my $parent_path = $args{parent_path} // q{};
    my $level       = $args{level}       // 0;
    my $a_langs     = $args{a_langs};
    my $a_map       = $args{a_map};

    return if $level > $MAX_DEPTH_LEVEL;

    my $html_path  = $config->{data}->{html_path};
    my $bread_path = $config->{data}->{bread_path};
    my $tpl_path   = $config->{templates}->{path_f};
    my $site_host  = $config->{site}->{host};

    my $sel = <<'EOF';
        SELECT
            id,
            navi_on,
            child_qty,
            nick
        FROM
            pages
        WHERE
            parent_id = ? AND hidden = 0
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($parent_id);
    while ( my ( $id, $navi_on, $child_qty, $nick ) = $sth->fetchrow_array() ) {
        # base path to this page (without lang)
        # TODO: Uril::Tree::page_path - get rid of recursion ?
        my $base_path = q{};
        if ($parent_id) {
            $base_path = $parent_path . q{/} . $nick;
        }

        # lang links, metatags and sitemap hrefs for this page
        my $h_langhref = Util::Langs::build_hrefs(
            a_langs   => $a_langs,
            base_path => $base_path,
            root_dir  => $root_dir,
            site_host => $site_host,
            tpl_path  => $tpl_path,
        );

        # lang versions of this page
        foreach my $h_lang ( @{$a_langs} ) {
            my $dir = $root_dir . $html_path . $h_lang->{lang_path} . $base_path;
            if ( !-d $dir ) {
                Util::Files::make_path( path => $dir );
            }

            # create breadcrumbs file
            my $a_chain = [];
            Util::Tree::get_chain(
                {
                    dbh     => $dbh,
                    lang_id => $h_lang->{lang_id},
                    id      => $id,
                },
                $a_chain
            );
            my $breadcrumbs = q{};
            my $ch_i        = 0;
            foreach my $h ( @{$a_chain} ) {
                my $path = Util::Tree::page_path(
                    dbh     => $dbh,
                    page_id => $h->{id},
                );
                if ( $ch_i == 0 ) {
                    $breadcrumbs .= Util::Renderer::parse_html(
                        root_dir => $root_dir,
                        tpl_path => $tpl_path . '/cat',
                        tpl_name => 'breadcrumb-home.html',
                        h_vars   => {
                            path => $h_lang->{lang_path} . $path,
                            name => $h->{name},
                        },
                    );
                }
                else {
                    $breadcrumbs .= Util::Renderer::parse_html(
                        root_dir => $root_dir,
                        tpl_path => $tpl_path . '/cat',
                        tpl_name => 'breadcrumb-item.html',
                        h_vars   => {
                            path => $h_lang->{lang_path} . $path,
                            name => $h->{name},
                        },
                    );
                }
                $ch_i++;
            }
            my $bread_fname = $id . q{-} . $h_lang->{lang_id} . '.html';
            Util::Files::write_file(
                file => $root_dir . $bread_path . q{/} . $bread_fname,
                body => $breadcrumbs,
            );

            # create mnavi, dnavi files
            gen_navi(
                dbh       => $dbh,
                config    => $config,
                root_dir  => $root_dir,
                lang_id   => $h_lang->{lang_id},
                lang_path => $h_lang->{lang_path},
                id_cur    => $id,
                parent_id => $parent_id,
                child_qty => $child_qty,
            );

            # build and collect sitemap item
            my $map_item = Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/cat',
                tpl_name => 'sitemap-item.xml',
                h_vars   => {
                    path          => $h_lang->{lang_path} . $base_path,
                    site_host     => $site_host,
                    cur_date      => $cur_date,
                    lang_maphrefs => $h_langhref->{maphrefs},
                },
            );
            push @{$a_map}, $map_item;
        }

        go_tree(
            dbh         => $dbh,
            config      => $config,
            root_dir    => $root_dir,
            cur_date    => $cur_date,
            parent_id   => $id,
            parent_path => $base_path,
            level       => $level + 1,
            a_langs     => $a_langs,
            a_map       => $a_map,
        );
    }
    $sth->finish();
    return;
}

sub gen_navi {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $config    = $args{config};
    my $root_dir  = $args{root_dir};
    my $lang_id   = $args{lang_id} // 1;
    my $lang_path = $args{lang_path} // q{};
    my $id_cur    = $args{id_cur} // 0;
    my $parent_id = $args{parent_id} || 1;
    my $child_qty = $args{child_qty} || 0;

    my $navi_path    = $config->{data}->{navi_path};
    my $tpl_path     = $config->{templates}->{path_f};
    my $tpl_path_gmi = $config->{templates}->{path_gmi};

    my $links_m   = q{}; # mobile menu
    my $links_d   = q{}; # desktop menu
    my $links_gmi = q{}; # gemini menu

    my $sel = <<'EOF';
        SELECT
            p.id,
            pm.value
        FROM
            pages AS p
            LEFT JOIN page_marks AS pm ON p.id = pm.page_id
        WHERE
            p.parent_id = ?
            AND p.hidden = 0
            AND p.navi_on = 1
            AND pm.lang_id = ?
            AND pm.name = 'page_name'
        ORDER BY p.priority DESC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $parent_id, $lang_id );
    while ( my ( $id, $page_name ) = $sth->fetchrow_array() ) {
        my $page_path = Util::Tree::page_path(
            dbh     => $dbh,
            page_id => $id,
        );

        my $suffix  = q{};
        my $h_child = {
            links_m => q{},
            links_d => q{},
        };
        if ( $id == $id_cur ) {
            $suffix  = '-cur';
            $h_child = _get_child_links(
                dbh          => $dbh,
                root_dir     => $root_dir,
                tpl_path     => $tpl_path,
                tpl_path_gmi => $tpl_path_gmi,
                lang_id      => $lang_id,
                lang_path    => $lang_path,
                parent_id    => $id_cur,
            );
        }

        $links_m .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => "mnavi-item$suffix.html",
            h_vars   => {
                path        => $lang_path . $page_path,
                name        => $page_name,
                child_links => $h_child->{links_m},
            },
        );

        $links_d .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => "dnavi-item$suffix.html",
            h_vars   => {
                path        => $lang_path . $page_path,
                name        => $page_name,
                child_links => $h_child->{links_d},
            },
        );

        if ($tpl_path_gmi) {
            $links_gmi .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path_gmi . '/cat',
                tpl_name => "navi-item$suffix.gmi",
                h_vars   => {
                    path        => $lang_path . $page_path,
                    name        => $page_name,
                    child_links => $h_child->{links_gmi},
                },
            );
        }
    }
    $sth->finish();

    my $mnavi_fname = 'm-' . $id_cur . q{-} . $lang_id . '.html';
    Util::Files::write_file(
        file => $root_dir . $navi_path . q{/} . $mnavi_fname,
        body => $links_m,
    );

    my $dnavi_fname = 'd-' . $id_cur . q{-} . $lang_id . '.html';
    Util::Files::write_file(
        file => $root_dir . $navi_path . q{/} . $dnavi_fname,
        body => $links_d,
    );

    if ($tpl_path_gmi) {
        my $gmi_navi_fname = $id_cur . q{-} . $lang_id . '.gmi';
        Util::Files::write_file(
            file => $root_dir . $navi_path . q{/} . $gmi_navi_fname,
            body => $links_gmi,
        );
    }

    return;
}

sub _get_child_links {
    my (%args) = @_;

    my $dbh          = $args{dbh};
    my $root_dir     = $args{root_dir};
    my $tpl_path     = $args{tpl_path};
    my $tpl_path_gmi = $args{tpl_path_gmi};
    my $lang_id      = $args{lang_id} // 1;
    my $lang_path    = $args{lang_path} // q{};
    my $parent_id    = $args{parent_id} // 0;

    my $child_links_m   = q{};
    my $child_links_d   = q{};
    my $child_links_gmi = q{};

    my $sel = <<'EOF';
        SELECT
            p.id,
            pm.value
        FROM
            pages AS p
            LEFT JOIN page_marks AS pm ON p.id = pm.page_id
        WHERE
            p.parent_id = ?
            AND p.hidden = 0
            AND p.navi_on = 1
            AND pm.lang_id = ?
            AND pm.name = 'page_name'
        ORDER BY p.priority DESC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $parent_id, $lang_id );
    while ( my ( $id, $page_name ) = $sth->fetchrow_array() ) {
        my $page_path = Util::Tree::page_path(
            dbh     => $dbh,
            page_id => $id,
        );

        $child_links_m .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => 'mnavi-child.html',
            h_vars   => {
                path => $lang_path . $page_path,
                name => $page_name,
            },
        );

        $child_links_d .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => 'dnavi-child.html',
            h_vars   => {
                path => $lang_path . $page_path,
                name => $page_name,
            },
        );

        if ($tpl_path_gmi) {
            $child_links_gmi .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path_gmi . '/cat',
                tpl_name => 'navi-child.gmi',
                h_vars   => {
                    path => $lang_path . $page_path,
                    name => $page_name,
                },
            );
        }
    }
    $sth->finish();

    return {
        links_m   => $child_links_m,
        links_d   => $child_links_d,
        links_gmi => $child_links_gmi,
    };
}

1;
