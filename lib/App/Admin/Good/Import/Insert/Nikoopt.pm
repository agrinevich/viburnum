package App::Admin::Good::Import::Insert::Nikoopt;

use strict;
use warnings;

use Const::Fast;

use Util::Csvtools;
use Util::Goods;
use Util::Renderer;
use Util::Texter;
use Util::Tree;
use Util::Langs;

our $VERSION = '1.1';

const my $BIG_QTY  => 999_999;
const my $MIN_SIZE => 10;
const my $TEN      => 10;
const my $HUNDRED  => 100;

const my $PAGE_TITLE_MAX_LENGTH => 255;

# cache
my %CATNAMES = ();

sub insert2db {
    my ( undef, %args ) = @_;

    my $app        = $args{app};
    my $sup_id     = $args{sup_id};
    my $cat_id     = $args{cat_id};
    my $input_file = $args{file};

    my $a_rows = Util::Csvtools::read_csv(
        {
            file => $input_file,
            mode => '<:encoding(UTF-8)',
            # mode => '<',
        },
        {
            binary           => 1,
            auto_diag        => 1,
            diag_verbose     => 1,
            eol              => qq{\n},
            sep_char         => q{;},
            blank_is_undef   => 1,
            empty_is_undef   => 1,
            allow_whitespace => 1,
            escape_char      => q{\\},
            # quote_char       => $quote_char,
            # allow_loose_quotes => 1,
            # allow_unquoted_escape => 1,
        }
    );
    # warn 'rowsqty=' . scalar @{$a_rows} . "\n";

    # get columns indexes from config
    my $section = 'supplier_' . $sup_id;
    my $h_sup   = {
        sup_id      => $sup_id,
        code_idx    => $app->config->{$section}->{code_idx},
        name_idx    => $app->config->{$section}->{name_idx},
        cat_idx     => $app->config->{$section}->{cat_idx},
        descr_idx   => $app->config->{$section}->{descr_idx},
        size_idx    => $app->config->{$section}->{size_idx},
        color_idx   => $app->config->{$section}->{color_idx},
        textile_idx => $app->config->{$section}->{textile_idx},
        price_idx   => $app->config->{$section}->{price_idx},
        images_idx  => $app->config->{$section}->{images_idx},
        margin      => $app->config->{$section}->{margin},
    };

    my $sel = q{SELECT LAST_INSERT_ID()};
    my $sth = $app->dbh->prepare($sel);

    my $ins1 = q{INSERT INTO goods (changed, sup_id, code, name, nick) VALUES (1, ?, ?, ?, ?)};
    my $sth1 = $app->dbh->prepare($ins1);

    my $ins2 = q{INSERT INTO goods_categories (good_id, cat_id) VALUES (?, ?)};
    my $sth2 = $app->dbh->prepare($ins2);

    #
    # FIXME !!! MD5 index
    #
    my $sel5 = q{SELECT id FROM goods_colors WHERE name = ?};
    my $sth5 = $app->dbh->prepare($sel5);

    my $sel6 = q{SELECT id FROM goods_sizes WHERE name = ?};
    my $sth6 = $app->dbh->prepare($sel6);

    my $ins3
        = q{INSERT INTO goods_offers (good_id, color_id, size_id, qty, price, price2) VALUES (?, ?, ?, ?, ?, ?)};
    my $sth3 = $app->dbh->prepare($ins3);

    my $ins4
        = q{INSERT INTO goods_versions (good_id, lang_id, name, descr, p_title, p_descr) VALUES (?, ?, ?, ?, ?, ?)};
    my $sth4 = $app->dbh->prepare($ins4);

    my $a_langs = Util::Langs::get_langs( dbh => $app->dbh );

    #
    # TODO: wrap as MySQL transaction
    #
    my $i = 0;
    foreach my $row ( @{$a_rows} ) {
        my $h = Util::Csvtools::row_values( $h_sup, $row );

        next if !$h->{code} || !$h->{name};
        next if $h->{price} !~ /\d+/mxsg;

        my $good_nick = Util::Goods::build_good_nick(
            sup_id => $sup_id,
            code   => $h->{code},
            # name   => $h->{name},
        );

        #
        # FIXME: 'good_name' depends on lang, move it to cycle
        #
        my $good_name = $h->{name};
        if ( $h->{textile} ) {
            $good_name .= q{ } . $h->{textile};
        }

        # goods
        $sth1->execute( $sup_id, $h->{code}, $good_name, $good_nick );

        # new good id
        $sth->execute();
        my ($good_id) = $sth->fetchrow_array();

        # insert (bind) goods_categories
        $sth2->execute( $good_id, $cat_id );

        # good_offers
        $sth5->execute( $h->{color} );
        my ($color_id) = $sth5->fetchrow_array();
        $color_id //= 0; # for this supplier good has only 1 color
        my $qty       = $BIG_QTY;
        my $price_out = $h->{price} * ( 1 + $h_sup->{margin} / $HUNDRED );
        my $a_sizes   = Util::Goods::parse_sizes( $h->{size} );
        foreach my $size ( @{$a_sizes} ) {
            $sth6->execute($size);
            my ($size_id) = $sth6->fetchrow_array();
            if ( !$size_id ) {
                $app->logger->error( 'unknown size: ' . $size . ' for ' . $h->{code} );
                next;
            }
            $sth3->execute( $good_id, $color_id, $size_id, $qty, $h->{price}, $price_out );
        }

        #
        # FIXME: 'good_name' depends on lang, move it to cycle
        #
        my $p_title = Util::Renderer::do_escape($good_name);
        $p_title = Util::Texter::cut_phrase( $p_title, $PAGE_TITLE_MAX_LENGTH );

        foreach my $h_lang ( @{$a_langs} ) {
            my $lang_id = $h_lang->{lang_id};

            my $cat_names = _get_cat_names(
                dbh     => $app->dbh,
                cat_id  => $cat_id,
                lang_id => $lang_id,
            );

            my $p_descr = Util::Goods::build_good_p_descr(
                cat_names   => $cat_names,
                good_name   => $good_name,
                lang_suffix => $h_lang->{lang_suffix},
                tpl_path    => $app->config->{templates}->{path_f},
                root_dir    => $app->root_dir,
            );
            $p_descr = Util::Renderer::do_escape($p_descr);
            $p_descr = Util::Texter::cut_phrase( $p_descr, $PAGE_TITLE_MAX_LENGTH );

            # goods versions
            $h->{descr} //= q{};
            $sth4->execute( $good_id, $lang_id, $good_name, $h->{descr}, $p_title, $p_descr );
        }

        # good_images ?
        # $h->{images};

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
