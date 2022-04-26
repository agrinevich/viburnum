package App::Admin::Good::Import::Update::Nikoopt;

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);

use Util::Csvtools;
use Util::Goods;
use Util::Renderer;
use Util::Texter;
use Util::Tree;
use Util::Langs;

our $VERSION = '1.1';

const my $BIG_QTY => 999_999;
const my $HUNDRED => 100;

const my $PAGE_TITLE_MAX_LENGTH => 255;

# cache
my %CATNAMES = ();

sub update2db {
    my ( undef, %args ) = @_;

    my $input_file = $args{file};
    my $sup_id     = $args{sup_id};
    my $config     = $args{config};
    my $logger     = $args{logger};
    my $dbh        = $args{dbh};
    my $root_dir   = $args{root_dir};

    my $a_rows = Util::Csvtools::read_csv(
        {
            file => $input_file,
            mode => '<',
            # mode => '<:encoding(UTF-8)',
        },
        {
            binary                => 1,
            auto_diag             => 1,
            diag_verbose          => 1,
            eol                   => qq{\n},
            sep_char              => q{;},
            blank_is_undef        => 1,
            empty_is_undef        => 1,
            allow_whitespace      => 1,
            allow_loose_quotes    => 1,
            allow_unquoted_escape => 1,
            # escape_char      => $escape_char,
            # quote_char       => $quote_char,
        }
    );

    Util::Goods::hide_goods(
        sup_id => $sup_id,
        config => $config,
        logger => $logger,
        dbh    => $dbh,
    );

    my $upd_qty = _update_goods(
        dbh      => $dbh,
        config   => $config,
        sup_id   => $sup_id,
        a_rows   => $a_rows,
        root_dir => $root_dir,
    );

    return $upd_qty // 0;
}

sub _update_goods {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $dbh      = $args{dbh};
    my $config   = $args{config};
    my $sup_id   = $args{sup_id};
    my $a_rows   = $args{a_rows};

    # get columns indexes from config
    my $section = 'supplier_' . $sup_id;
    my $h_sup   = {
        sup_id      => $sup_id,
        code_idx    => $config->{$section}->{code_idx},
        name_idx    => $config->{$section}->{name_idx},
        cat_idx     => $config->{$section}->{cat_idx},
        descr_idx   => $config->{$section}->{descr_idx},
        size_idx    => $config->{$section}->{size_idx},
        color_idx   => $config->{$section}->{color_idx},
        textile_idx => $config->{$section}->{textile_idx},
        price_idx   => $config->{$section}->{price_idx},
        images_idx  => $config->{$section}->{images_idx},
        margin      => $config->{$section}->{margin},
    };

    my $q1   = q{SELECT id FROM goods WHERE sup_id = ? AND code = ?};
    my $sth1 = $dbh->prepare($q1);

    my $q21   = q{UPDATE goods SET hidden = 0, name = ?, nick = ? WHERE sup_id = ? AND code = ?};
    my $sth21 = $dbh->prepare($q21);

    my $qcat   = 'SELECT cat_id FROM goods_categories WHERE good_id = ? LIMIT 1';
    my $sthcat = $dbh->prepare($qcat);

    #
    # FIXME !!! MD5 index
    #
    my $sel22 = q{SELECT id FROM goods_colors WHERE name = ?};
    my $sth22 = $dbh->prepare($sel22);

    my $sel23 = q{SELECT id FROM goods_sizes WHERE name = ?};
    my $sth23 = $dbh->prepare($sel23);

    my $q24
        = q{INSERT INTO goods_offers (good_id, color_id, size_id, qty, price, price2) VALUES (?, ?, ?, ?, ?, ?)};
    my $sth24 = $dbh->prepare($q24);

    my $q25
        = q{UPDATE goods_versions SET name = ?, descr = ?, p_title = ?, p_descr = ? WHERE good_id = ? AND lang_id = ?};
    my $sth25 = $dbh->prepare($q25);

    my $q26   = q{INSERT IGNORE INTO goods_images (good_id, num, url) VALUES (?, ?, ?)};
    my $sth26 = $dbh->prepare($q26);

    my $q31   = q{INSERT INTO goods (changed, sup_id, code, name, nick) VALUES (1, ?, ?, ?, ?)};
    my $sth31 = $dbh->prepare($q31);

    my $q32   = q{SELECT LAST_INSERT_ID()};
    my $sth32 = $dbh->prepare($q32);

    my $q33
        = q{INSERT INTO goods_versions (name, descr, p_title, p_descr, good_id, lang_id) VALUES (?, ?, ?, ?, ?, ?)};
    my $sth33 = $dbh->prepare($q33);

    my $a_langs = Util::Langs::get_langs( dbh => $dbh );

    my $i = 0;
    foreach my $row ( @{$a_rows} ) {
        my $h = Util::Csvtools::row_values( $h_sup, $row );

        next if !$h->{code} || !$h->{name};
        next if $h->{price} !~ /\d+/mxsg;

        # find good by supplier and SKU code
        $sth1->execute( $sup_id, $h->{code} );
        my ($good_id) = $sth1->fetchrow_array();

        # find any category for this good
        $sthcat->execute($good_id);
        my ($cat_id) = $sthcat->fetchrow_array();

        my $good_nick = Util::Goods::build_good_nick(
            sup_id => $sup_id,
            code   => $h->{code},
            # name   => $h->{name},
        );

        #
        # FIXME: 'good_name' depends on lang
        #
        my $good_name = $h->{name};
        if ( $h->{textile} ) {
            $good_name .= q{ } . $h->{textile};
        }

        #
        # FIXME: 'good_name' depends on lang
        #
        my $p_title = Util::Renderer::do_escape($good_name);
        $p_title = Util::Texter::cut_phrase( $p_title, $PAGE_TITLE_MAX_LENGTH );

        foreach my $h_lang ( @{$a_langs} ) {
            my $lang_id = $h_lang->{lang_id};

            my $cat_names = _get_cat_names(
                dbh     => $dbh,
                cat_id  => $cat_id,
                lang_id => $lang_id,
            );
            my $p_descr = Util::Goods::build_good_p_descr(
                cat_names   => $cat_names,
                good_name   => $good_name,
                lang_suffix => $h_lang->{lang_suffix},
                tpl_path    => $config->{templates}->{path_f},
                root_dir    => $root_dir,
            );
            $p_descr = Util::Renderer::do_escape($p_descr);
            $p_descr = Util::Texter::cut_phrase( $p_descr, $PAGE_TITLE_MAX_LENGTH );

            if ($good_id) {
                # update goods
                $sth21->execute( $good_name, $good_nick, $sup_id, $h->{code} );

                # goods versions
                $h->{descr} //= q{};
                $sth25->execute( $good_name, $h->{descr}, $p_title, $p_descr, $good_id, $lang_id );
            }
            else {
                # add to goods
                $sth31->execute( $sup_id, $h->{code}, $good_name, $good_nick );

                # read new good_id
                $sth32->execute();
                ($good_id) = $sth32->fetchrow_array();

                #
                # TODO: binding to category ? or bind manually via 'lost'
                #

                $h->{descr} //= q{};
                $sth33->execute( $good_name, $h->{descr}, $p_title, $p_descr, $good_id, $lang_id );
            }
        }

        # add good_offers

        my $price_out = $h->{price} * ( 1 + $h_sup->{margin} / $HUNDRED );

        $sth22->execute( $h->{color} );
        my ($color_id) = $sth22->fetchrow_array();
        $color_id //= 0; # for 'Nickoopt' each good has only 1 color

        my $a_sizes = Util::Goods::parse_sizes( $h->{size} );

        foreach my $size ( @{$a_sizes} ) {
            $sth23->execute($size);
            my ($size_id) = $sth23->fetchrow_array();

            if ( !$size_id ) {
                carp( 'unknown size: ' . $size . ' for ' . $h->{code} );
                next;
            }

            $sth24->execute( $good_id, $color_id, $size_id, $BIG_QTY, $h->{price}, $price_out );
        }

        # add URLs of images
        my @urls = split /,/xms, $h->{images};
        my $num  = 0;
        foreach my $url (@urls) {
            next if !$url;
            #
            # TODO: if file exists already set path right here
            #
            $sth26->execute( $good_id, $num, $url );
            $num++;
        }

        $i++;
    }

    return $i;
}

# Women _ Dresses
sub _get_cat_names {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $cat_id  = $args{cat_id};
    my $lang_id = $args{lang_id};

    if ( !exists $CATNAMES{$cat_id} ) {
        my @page_chain = ();
        Util::Tree::get_chain(
            {
                dbh     => $dbh,
                id      => $cat_id,
                lang_id => $lang_id,
            },
            \@page_chain
        );

        my $cat_names = q{};
        my $sep       = q{};
        foreach my $h_page (@page_chain) {
            $cat_names .= $sep . $h_page->{name};
            $sep = q{ };
        }

        $CATNAMES{$cat_id} = $cat_names;
    }

    return $CATNAMES{$cat_id};
}

1;
