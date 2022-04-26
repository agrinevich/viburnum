package App::Worker::CreateShop;

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
use Util::Goods;
use Util::Supplier;
use Util::Tree;

our $VERSION = '1.1';

const my $MAX_DEPTH_LEVEL => 9;

sub work {
    my ( $class, $job ) = @_;

    my %args = @{ $job->arg };

    my $root_dir  = $args{root_dir};
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

    # there can be only 1 shop on site
    my $shop_root_id = Util::Tree::find_shop_root( dbh => $dbh );

    my $shop_path = Util::Tree::page_path(
        dbh     => $dbh,
        page_id => $shop_root_id,
    );

    my $html_path = $config->{data}->{html_path};

    # we need 'buy' dir for detailed pages in each lang version
    foreach my $h_lang ( @{$a_langs} ) {
        my $buy_dir = $root_dir . $html_path . $h_lang->{lang_path} . $shop_path . '/buy';
        if ( !-d $buy_dir ) {
            Util::Files::make_path( path => $buy_dir );
        }
    }

    go_tree(
        dbh         => $dbh,
        config      => $config,
        root_dir    => $root_dir,
        parent_id   => $shop_root_id,
        parent_path => $shop_path,
        home_path   => $shop_path,
        level       => 0,
        mode        => 1,
        a_langs     => [ @{$a_langs} ],
    );
    carp('generated: shop pages');

    $job->completed();
    return;
}

#
# TODO: get rid of recursion
# TODO: add paging like in 'notes'
# TODO: move lang cycle outside like in 'notes'
#
sub go_tree {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $config    = $args{config};
    my $root_dir  = $args{root_dir};
    my $mode      = $args{mode};
    my $a_langs   = $args{a_langs};
    my $home_path = $args{home_path} // q{};

    my $parent_id   = $args{parent_id}   // 0;
    my $parent_path = $args{parent_path} // q{};
    my $level       = $args{level};

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

        my $h_page = gen_list(
            {
                dbh         => $dbh,
                config      => $config,
                root_dir    => $root_dir,
                id          => $id,
                parent_id   => $parent_id,
                parent_path => $parent_path,
                home_path   => $home_path,
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
            home_path   => $home_path,
            level       => $level + 1,
            mode        => $mode,
            a_langs     => $a_langs,
        );
    }
    $sth->finish();
    return;
}

sub gen_list {
    my ($h_args) = @_;

    my $dbh       = $h_args->{dbh};
    my $config    = $h_args->{config};
    my $root_dir  = $h_args->{root_dir};
    my $home_path = $h_args->{home_path};

    my $id          = $h_args->{id};
    my $parent_id   = $h_args->{parent_id};
    my $parent_path = $h_args->{parent_path};
    my $changed     = $h_args->{changed};
    my $good_qty    = $h_args->{good_qty};
    my $name        = $h_args->{name};
    my $nick        = $h_args->{nick};
    my $a_langs     = $h_args->{a_langs};
    my $mode        = $h_args->{mode};

    my $html_path   = $config->{data}->{html_path};
    my $bread_path  = $config->{data}->{bread_path};
    my $navi_path   = $config->{data}->{navi_path};
    my $images_path = $config->{data}->{images_path};
    my $goods_path  = $config->{data}->{goods_path};
    my $tpl_path    = $config->{templates}->{path_f};
    my $site_host   = $config->{site}->{host};

    # base path to this page (without lang)
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

    # generate lang versions for this page
    foreach my $h_lang ( @{$a_langs} ) {
        my $h_marks = Util::Tree::get_marks(
            dbh     => $dbh,
            page_id => $id,
            lang_id => $h_lang->{lang_id},
        );

        $h_marks->{lang_metatags} = $h_langhref->{metatags};
        $h_marks->{lang_links}    = $h_langhref->{links};
        $h_marks->{site_host}     = $site_host;

        my $navi_fname = $id . q{-} . $h_lang->{lang_id} . '.html';
        my $navi       = Util::Files::read_file(
            file => $root_dir . $navi_path . q{/} . $navi_fname,
        );
        $h_marks->{navi} = $navi;

        my $bread_fname = $id . q{-} . $h_lang->{lang_id} . '.html';
        my $breadcrumbs = Util::Files::read_file(
            file => $root_dir . $bread_path . q{/} . $bread_fname,
        );
        $h_marks->{breadcrumbs} = $breadcrumbs;

        my $goods = build_goods_list(
            dbh         => $dbh,
            root_dir    => $root_dir,
            tpl_path    => $tpl_path,
            page_id     => $id,
            lang_id     => $h_lang->{lang_id},
            lang_nick   => $h_lang->{lang_nick},
            lang_path   => $h_lang->{lang_path},
            lang_suffix => $h_lang->{lang_suffix},
            html_path   => $html_path,
            home_path   => $home_path,
            goods_path  => $goods_path,
            site_host   => $site_host,
            h_marks     => $h_marks,
        );

        $h_marks->{page_main} = Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/good',
            tpl_name => 'list.html',
            h_vars   => {
                name  => $name,
                links => q{links here}, # TODO
                goods => $goods,
            },
        );

        Util::Renderer::write_html(
            $h_marks,
            {
                dbh       => $dbh,
                root_dir  => $root_dir,
                html_path => $html_path,
                tpl_path  => $tpl_path,
                tpl_file  => q{layout.html},
                out_path  => $h_lang->{lang_path} . $base_path,
                out_file  => q{index.html},
            }
        );
    }

    return {
        base_path => $base_path,
    };
}

sub build_goods_list {
    my (%args) = @_;

    my $page_id     = $args{page_id}     // 0;
    my $lang_id     = $args{lang_id}     // 1;
    my $lang_nick   = $args{lang_nick}   // q{};
    my $lang_path   = $args{lang_path}   // q{};
    my $lang_suffix = $args{lang_suffix} // q{};
    my $home_path   = $args{home_path}   // q{};
    my $goods_path  = $args{goods_path}  // q{};
    my $root_dir    = $args{root_dir}    // q{};
    my $tpl_path    = $args{tpl_path}    // q{};
    my $html_path   = $args{html_path}   // q{};
    my $site_host   = $args{site_host}   // q{};
    my $h_marks     = $args{h_marks};
    my $dbh         = $args{dbh};

    my $h_page_marks = { %{$h_marks} };

    my $a_goods = Util::Goods::list(
        dbh       => $dbh,
        f_cat_str => $page_id,
        lang_id   => $lang_id,
        order_by  => 'price',
    );
    my $list = q{};
    my $i    = 0;
    foreach my $h_good ( @{$a_goods} ) {
        $i++;

        my $a_offers = Util::Goods::offers(
            dbh     => $dbh,
            good_id => $h_good->{id},
        );
        my %sizes    = ();
        my %colors_n = ();
        my %colors_v = ();
        my @prices   = ();
        my $offers_d = q{};
        foreach my $h ( @{$a_offers} ) {
            $sizes{ $h->{size_id} }     = $h->{size_name};
            $colors_n{ $h->{color_id} } = $h->{color_name};
            $colors_v{ $h->{color_id} } = $h->{color_value};

            push @prices, $h->{price2};

            $offers_d .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'offer-d.html',
                h_vars   => $h,
            );
        }
        if ( !$offers_d ) {
            $offers_d = Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'offer-d-unavail.html',
                h_vars   => {},
            );
        }

        my $sizes = q{};
        foreach my $size_id ( keys %sizes ) {
            $sizes .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'offer-size.html',
                h_vars   => { size_name => $sizes{$size_id} },
            );
        }

        my $colors = q{};
        foreach my $color_id ( keys %colors_n ) {
            $colors .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'offer-color.html',
                h_vars   => {
                    color_name  => $colors_n{$color_id},
                    color_value => $colors_v{$color_id},
                },
            );
        }

        my @prices_sorted = sort @prices;
        my $price_min     = $prices_sorted[0];

        # good details page
        my $path = $lang_path . $home_path . $goods_path . q{/} . $h_good->{nick} . '.html';

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/good',
            tpl_name => 'list-item.html',
            h_vars   => {
                i           => $i,
                id          => $h_good->{id},
                sup_id      => $h_good->{sup_id},
                price       => $price_min,
                code        => $h_good->{code},
                name        => Util::Renderer::do_escape( $h_good->{name} ),
                nick        => $h_good->{nick},
                path        => $path,
                sizes       => $sizes,
                colors      => $colors,
                lang_nick   => $lang_nick,
                img_path_sm => $h_good->{img_path_sm},
                img_path_la => $h_good->{img_path_la},
            },
        );

        gen_good_details(
            {
                dbh         => $dbh,
                home_path   => $home_path,
                goods_path  => $goods_path,
                tpl_path    => $tpl_path,
                html_path   => $html_path,
                site_host   => $site_host,
                root_dir    => $root_dir,
                id          => $h_good->{id},
                sup_id      => $h_good->{sup_id},
                code        => $h_good->{code},
                name        => $h_good->{name},
                nick        => $h_good->{nick},
                descr       => $h_good->{descr},
                p_title     => $h_good->{p_title},
                p_descr     => $h_good->{p_descr},
                offers_d    => $offers_d,
                lang_nick   => $lang_nick,
                lang_id     => $lang_id,
                lang_path   => $lang_path,
                lang_suffix => $lang_suffix,
                h_marks     => $h_page_marks,
            }
        );
    }

    return $list;
}

sub gen_good_details {
    my ($h_args) = @_;

    my $dbh         = $h_args->{dbh};
    my $id          = $h_args->{id};
    my $sup_id      = $h_args->{sup_id};
    my $code        = $h_args->{code};
    my $name        = $h_args->{name};
    my $nick        = $h_args->{nick};
    my $descr       = $h_args->{descr};
    my $p_title     = $h_args->{p_title};
    my $p_descr     = $h_args->{p_descr};
    my $offers_d    = $h_args->{offers_d};
    my $lang_id     = $h_args->{lang_id};
    my $lang_nick   = $h_args->{lang_nick};
    my $lang_path   = $h_args->{lang_path};
    my $lang_suffix = $h_args->{lang_suffix};
    my $home_path   = $h_args->{home_path};
    my $goods_path  = $h_args->{goods_path};
    my $tpl_path    = $h_args->{tpl_path};
    my $html_path   = $h_args->{html_path};
    my $site_host   = $h_args->{site_host};
    my $root_dir    = $h_args->{root_dir};
    my $h_marks     = $h_args->{h_marks};

    my $h_sup = Util::Supplier::one(
        dbh => $dbh,
        id  => $sup_id,
    );
    my $sup_info = sprintf '%s, %s', $h_sup->{title}, $h_sup->{city};

    my $a_images = Util::Goods::images(
        dbh     => $dbh,
        good_id => $id,
    );
    my $img_list = q{};
    foreach my $h ( @{$a_images} ) {
        $h->{name} = $name;
        $img_list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/good',
            tpl_name => 'details-image.html',
            h_vars   => $h,
        );
    }
    $h_args->{img_list} = $img_list;

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_name => 'details.html',
        h_vars   => $h_args,
    );

    $h_marks->{page_main}  = $body;
    $h_marks->{page_title} = $p_title;
    $h_marks->{page_descr} = $p_descr;

    Util::Renderer::write_html(
        $h_marks,
        {
            dbh       => $dbh,
            root_dir  => $root_dir,
            html_path => $html_path,
            tpl_path  => $tpl_path,
            tpl_file  => 'layout.html',
            out_path  => $lang_path . $home_path . $goods_path,
            out_file  => $nick . q{.html},
        }
    );

    return;
}

1;
