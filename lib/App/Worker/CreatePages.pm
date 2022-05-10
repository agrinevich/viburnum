package App::Worker::CreatePages;

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
use Util::Tree;
use Util::Texter;

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

    my $a_langs = Util::Langs::get_langs( dbh => $dbh );

    # create static pages (mode=0)
    go_tree(
        dbh         => $dbh,
        config      => $config,
        root_dir    => $root_dir,
        parent_id   => 0,
        parent_path => q{},
        level       => 0,
        mode        => 0,
        a_langs     => [ @{$a_langs} ],
    );
    carp('generated: static pages');

    $job->completed();
    return;
}

sub go_tree {
    my (%args) = @_;

    my $dbh      = $args{dbh};
    my $config   = $args{config};
    my $root_dir = $args{root_dir};

    my $parent_id   = $args{parent_id}   // 0;
    my $parent_path = $args{parent_path} // q{};
    my $level       = $args{level}       // 0;
    my $mode        = $args{mode}        // 0;
    my $a_langs     = $args{a_langs};

    return if $level > $MAX_DEPTH_LEVEL;

    my $sel = <<'EOF';
        SELECT
            id,
            changed,
            good_qty,
            name,
            nick
        FROM
            pages
        WHERE
            parent_id = ? AND mode = ? AND hidden = 0
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $parent_id, $mode );
    while ( my ( $id, $changed, $good_qty, $name, $nick ) = $sth->fetchrow_array() ) {

        my $h_page = gen_page(
            {
                dbh         => $dbh,
                config      => $config,
                root_dir    => $root_dir,
                id          => $id,
                parent_id   => $parent_id,
                parent_path => $parent_path,
                changed     => $changed,
                good_qty    => $good_qty,
                name        => $name,
                nick        => $nick,
                a_langs     => $a_langs,
                mode        => $mode,
            }
        );

        go_tree(
            dbh         => $dbh,
            config      => $config,
            root_dir    => $root_dir,
            parent_id   => $id,
            parent_path => $h_page->{base_path},
            level       => $level + 1,
            mode        => $mode,
            a_langs     => $a_langs,
        );
    }
    $sth->finish();
    return;
}

sub gen_page {
    my ($h_args) = @_;

    my $dbh      = $h_args->{dbh};
    my $config   = $h_args->{config};
    my $root_dir = $h_args->{root_dir};

    my $id          = $h_args->{id};
    my $parent_id   = $h_args->{parent_id};
    my $parent_path = $h_args->{parent_path};
    my $changed     = $h_args->{changed};
    my $mode        = $h_args->{mode};
    my $good_qty    = $h_args->{good_qty};
    my $name        = $h_args->{name};
    my $nick        = $h_args->{nick};
    my $a_langs     = $h_args->{a_langs};

    my $html_path    = $config->{data}->{html_path};
    my $images_path  = $config->{data}->{images_path};
    my $goods_path   = $config->{data}->{goods_path};
    my $bread_path   = $config->{data}->{bread_path};
    my $navi_path    = $config->{data}->{navi_path};
    my $tpl_path     = $config->{templates}->{path_f};
    my $tpl_path_gmi = $config->{templates}->{path_gmi};
    my $site_host    = $config->{site}->{host};

    # base path to this page (without lang)
    my $base_path = q{};
    if ($parent_id) {
        $base_path = $parent_path . q{/} . $nick;
    }

    # lang links, metatags and sitemap hrefs for this page
    my $h_langhref = Util::Langs::build_hrefs(
        a_langs      => $a_langs,
        base_path    => $base_path,
        root_dir     => $root_dir,
        site_host    => $site_host,
        tpl_path     => $tpl_path,
        tpl_path_gmi => $tpl_path_gmi,
    );

    # generate lang versions for this page
    foreach my $h_lang ( @{$a_langs} ) {
        # my $dir = $root_dir . $html_path . $h_lang->{lang_path} . $base_path;
        # if ( !-d $dir ) {
        #     Util::Files::make_path( path => $dir );
        # }

        my $h_marks = Util::Tree::get_marks(
            dbh     => $dbh,
            page_id => $id,
            lang_id => $h_lang->{lang_id},
        );

        $h_marks->{lang_metatags} = $h_langhref->{metatags};
        $h_marks->{lang_links}    = $h_langhref->{links};
        $h_marks->{site_host}     = $site_host;

        my $mnavi_fname = 'm-' . $id . q{-} . $h_lang->{lang_id} . '.html';
        my $mnavi       = Util::Files::read_file(
            file => $root_dir . $navi_path . q{/} . $mnavi_fname,
        );
        $h_marks->{mnavi} = $mnavi;

        my $dnavi_fname = 'd-' . $id . q{-} . $h_lang->{lang_id} . '.html';
        my $dnavi       = Util::Files::read_file(
            file => $root_dir . $navi_path . q{/} . $dnavi_fname,
        );
        $h_marks->{dnavi} = $dnavi;

        my $bread_fname = $id . q{-} . $h_lang->{lang_id} . '.html';
        my $breadcrumbs = Util::Files::read_file(
            file => $root_dir . $bread_path . q{/} . $bread_fname,
        );
        $h_marks->{breadcrumbs} = $breadcrumbs;

        # create static index.html page
        Util::Renderer::write_html(
            $h_marks,
            {
                dbh       => $dbh,
                root_dir  => $root_dir,
                html_path => $html_path,
                tpl_path  => $tpl_path,
                tpl_file  => 'layout.html',
                out_path  => $h_lang->{lang_path} . $base_path,
                out_file  => 'index.html',
            }
        );

        # and create half-ready layout template for 'user' app
        my %umarks = %{$h_marks};
        $umarks{page_main}  = '[% page_main %]';
        $umarks{lang_links} = '[% lang_links %]';
        Util::Renderer::write_html(
            \%umarks,
            {
                dbh       => $dbh,
                root_dir  => $root_dir,
                html_path => $html_path,
                tpl_path  => $tpl_path,
                tpl_file  => 'layout.html',
                out_path  => $h_lang->{lang_path} . $base_path,
                out_file  => 'layout-user.html',
            }
        );

        if ($tpl_path_gmi) {
            $h_marks->{gmi_lang_links} = $h_langhref->{gmi_links};

            my $navi_fname = $id . q{-} . $h_lang->{lang_id} . '.gmi';
            $h_marks->{gmi_navi} = Util::Files::read_file(
                file => $root_dir . $navi_path . q{/} . $navi_fname,
            );

            $h_marks->{gmi_main} = Util::Texter::html2gmi(
                str => $h_marks->{page_main},
            );

            Util::Renderer::write_html(
                $h_marks,
                {
                    dbh       => $dbh,
                    root_dir  => $root_dir,
                    html_path => $html_path,
                    tpl_path  => $tpl_path_gmi,
                    tpl_file  => 'layout.gmi',
                    out_path  => $h_lang->{lang_path} . $base_path,
                    out_file  => 'index.gmi',
                }
            );
        }
    }

    return {
        base_path => $base_path,
    };
}

1;
