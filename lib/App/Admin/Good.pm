package App::Admin::Good;

use strict;
use warnings;

use Util::Renderer;
use Util::Supplier;
use Util::Langs;
use Util::Goods;
use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my @cat_ids = $o_params->get_all('f_cat');
    my $f_code  = $o_params->{f_code} // q{};
    my $f_name  = $o_params->{f_name} // q{};
    my $f_lost  = $o_params->{f_lost} // 0;
    my $f_sup   = $o_params->{f_sup} // 0;

    my $h_lang = Util::Langs::get_lang(
        dbh     => $app->dbh,
        lang_id => 1,
    );
    my $lang_id     = $h_lang->{lang_id};
    my $lang_nick   = $h_lang->{lang_nick};
    my $lang_path   = $h_lang->{lang_path};
    my $lang_suffix = $h_lang->{lang_suffix};

    my $root_dir    = $app->root_dir;
    my $tpl_path    = $app->config->{templates}->{path};
    my $images_path = $app->config->{data}->{images_path};
    my $site_host   = $app->config->{site}->{host};
    my $goods_path  = $lang_path . $app->config->{data}->{goods_path};

    my $margin = q{};
    if ($f_sup) {
        my $section = 'supplier_' . $f_sup;
        $margin = $app->config->{$section}->{margin};
    }

    my $f_cat_str = join q{,}, @cat_ids;

    my $a_goods = [];
    if ( $f_code || $f_name || $f_lost || $f_sup || $f_cat_str ) {
        $a_goods = Util::Goods::list(
            f_code    => $f_code,
            f_name    => $f_name,
            f_cat_str => $f_cat_str,
            f_lost    => $f_lost,
            f_sup     => $f_sup,
            lang_id   => $lang_id,
            dbh       => $app->dbh,
        );
    }

    my $tpl_list = 'list.html';
    my $tpl_item = 'list-item.html';
    if ($f_lost) {
        $tpl_list = 'lost.html';
        $tpl_item = 'lost-item.html';
    }

    my $items = q{};
    my $qty   = 0;

    foreach my $h ( @{$a_goods} ) {
        $qty++;
        my $path = $goods_path . q{/} . $h->{nick} . '.html';

        my $a_offers = Util::Goods::offers(
            dbh     => $app->dbh,
            good_id => $h->{id},
        );

        my $sizes  = q{};
        my @prices = ();
        foreach my $ho ( @{$a_offers} ) {
            $sizes .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'offer-size.html',
                h_vars   => $ho,
            );

            push @prices, $ho->{price2};
        }
        my @prices_sorted = sort @prices;
        my $price_min     = $prices_sorted[0];

        # FIXME: refactor to general scheme!
        # this sup has single color for each good
        # ???
        my $h_offer_1   = $a_offers->[0];
        my $color_value = $h_offer_1->{color_value};

        $items .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/good',
            tpl_name => $tpl_item,
            h_vars   => {
                id          => $h->{id},
                sup_id      => $h->{sup_id},
                name        => $h->{name},
                nick        => $h->{nick},
                code        => $h->{code},
                img_path_sm => $h->{img_path_sm},
                i           => $qty,
                path        => $path,
                site_host   => $site_host,
                sizes       => $sizes,
                color       => $color_value,
                price       => $price_min,
                lang_nick   => $lang_nick,
            },
        );
    }

    my $shop_root_id = Util::Tree::find_shop_root( dbh => $app->dbh );

    my %cat_binded  = map { $_ => 1 } @cat_ids;
    my $cat_options = Util::Tree::build_tree(
        {
            dbh        => $app->dbh,
            root_dir   => $root_dir,
            tpl_path   => $tpl_path,
            tpl_name   => 'option',
            parent_id  => $shop_root_id,
            level      => 0,
            h_selected => {%cat_binded},
        }
    );

    my $a_suppliers = Util::Supplier::list( dbh => $app->dbh );
    my $sup_options = Util::Renderer::build_options(
        items    => $a_suppliers,
        id_sel   => $f_sup,
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_file => 'sup-option.html',
    );

    my $new_img_qty = Util::Goods::new_img_qty( dbh => $app->dbh );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_name => $tpl_list,
        h_vars   => {
            list        => $items,
            qty         => $qty,
            new_img_qty => $new_img_qty,
            cat_options => $cat_options,
            sup_options => $sup_options,
            f_code      => $f_code,
            f_name      => $f_name,
            f_lost      => $f_lost,
            f_cat       => $f_cat_str,
            f_sup       => $f_sup,
            margin      => $margin,
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

1;
