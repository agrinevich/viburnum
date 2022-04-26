package Util::Goods;

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);

use Util::Renderer;
use Util::Texter;

our $VERSION = '1.1';

const my $MIN_SIZE             => 10;
const my $TEN                  => 10;
const my $FILE_NAME_MAX_LENGTH => 32;

sub list {
    my (%args) = @_;

    my $f_code    = $args{f_code}    // q{};
    my $f_name    = $args{f_name}    // q{};
    my $f_cat_str = $args{f_cat_str} // q{};
    my $f_lost    = $args{f_lost}    // 0;
    my $f_sup     = $args{f_sup}     // 0;
    my $lang_id   = $args{lang_id}   // 1;
    my $order_by  = $args{order_by}  // q{};
    my $dbh       = $args{dbh};

    my @result = ();

    my $sel = <<'EOF';
        SELECT
            g.id, g.sup_id, g.code, gv.name, g.nick, g.img_path_sm, g.img_path_la, gv.descr, gv.p_title, gv.p_descr
        FROM goods AS g
        LEFT JOIN goods_categories AS gc
            ON g.id = gc.good_id
        LEFT JOIN goods_versions AS gv
            ON g.id = gv.good_id
        WHERE g.hidden = 0
        AND gv.lang_id = ?
EOF
    if ($f_lost)    { $sel .= q{ AND gc.cat_id IS NULL }; }
    if ($f_cat_str) { $sel .= qq{ AND gc.cat_id IN ($f_cat_str) }; }
    if ($f_sup)     { $sel .= qq{ AND g.sup_id = $f_sup }; }
    if ($f_code)    { $sel .= qq{ AND g.code LIKE "%${f_code}%" }; }
    if ($f_name)    { $sel .= qq{ AND gv.name LIKE "%${f_name}%" }; }
    $sel .= ' GROUP BY g.id';
    if ( $order_by eq 'price' ) {
        $sel .= ' ORDER BY g.price ASC';
    }
    else {
        $sel .= ' ORDER BY gv.name ASC';
    }
    my $sth = $dbh->prepare($sel);
    $sth->execute($lang_id);

    while (
        my (
            $id, $sup_id, $code, $name, $nick, $img_path_sm, $img_path_la, $descr, $p_title,
            $p_descr
        )
        = $sth->fetchrow_array()
    ) {
        push @result, {
            id          => $id,
            sup_id      => $sup_id,
            code        => $code,
            name        => $name,
            nick        => $nick,
            img_path_sm => $img_path_sm,
            img_path_la => $img_path_la,
            descr       => $descr,
            p_title     => $p_title,
            p_descr     => $p_descr,
        };
    }

    $sth->finish();
    return \@result;
}

sub offers {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $good_id = $args{good_id};

    my @offers = ();

    my $sel = <<'EOF';
        SELECT
            go.id, go.color_id, go.size_id, go.price, go.price2, go.discount, go.qty,
            gc.name, gc.value,
            gs.name
        FROM goods_offers AS go
        LEFT JOIN goods_colors AS gc
            ON go.color_id = gc.id
        LEFT JOIN goods_sizes AS gs
            ON go.size_id = gs.id
        WHERE go.good_id = ?
        AND go.qty > 0
        ORDER BY go.color_id ASC, go.size_id ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($good_id);
    while (
        my (
            $id,         $color_id, $size_id, $price, $price2, $discount, $qty,
            $color_name, $color_value,
            $size_name
        )
        = $sth->fetchrow_array()
    ) {
        my $price_f  = sprintf '%.2f', $price;
        my $price2_f = sprintf '%.2f', $price2;
        push @offers, {
            good_id     => $good_id,
            id          => $id,
            color_id    => $color_id,
            color_name  => $color_name // q{-},
            color_value => $color_value // q{#EEEEEE},
            size_id     => $size_id,
            size_name   => $size_name,
            price       => $price_f,
            price2      => $price2_f,
            discount    => $discount,
            qty         => $qty,
        };
    }
    $sth->finish();

    return \@offers;
}

sub images {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $good_id = $args{good_id};

    my @images = ();

    my $sel = <<'EOF';
        SELECT id, num, url, path_sm, path_la
        FROM goods_images
        WHERE good_id = ?
        AND path_sm <> ''
        AND path_la <> ''
        ORDER BY num ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($good_id);
    while ( my ( $id, $num, $url, $path_sm, $path_la ) = $sth->fetchrow_array() ) {
        push @images, {
            id      => $id,
            num     => $num,
            url     => $url,
            path_sm => $path_sm,
            path_la => $path_la,
        };
    }
    $sth->finish();

    return \@images;
}

sub delete_goods_by_sup {
    my (%args) = @_;

    my $app    = $args{app};
    my $sup_id = $args{sup_id};

    my $sel        = qq{SELECT g.id FROM goods AS g WHERE g.sup_id=$sup_id};
    my $a_good_ids = $app->dbh->selectcol_arrayref($sel);

    foreach my $good_id ( @{$a_good_ids} ) {
        delete_good_by_id(
            app     => $app,
            good_id => $good_id,
        );
    }

    # $app->dbh->do(qq{DELETE FROM sess_goods WHERE sup_id = $sup_id})
    # 	or
    # 	$app->logger->error( 'Failed to delete from sess_goods: ' . $app->dbh->errstr );

    return;
}

#
# FIXME: wrap in mysql transaction
#
sub delete_good_by_id {
    my (%args) = @_;

    my $app     = $args{app};
    my $good_id = $args{good_id};

    $app->dbh->do(qq{DELETE FROM goods_offers WHERE good_id = $good_id})
        or $app->logger->error( $app->dbh->errstr );

    $app->dbh->do(qq{DELETE FROM goods_versions WHERE good_id = $good_id})
        or $app->logger->error( $app->dbh->errstr );

    $app->dbh->do(qq{DELETE FROM goods_categories WHERE good_id = $good_id})
        or $app->logger->error( $app->dbh->errstr );

    $app->dbh->do(qq{DELETE FROM goods_images WHERE good_id = $good_id})
        or $app->logger->error( $app->dbh->errstr );

    $app->dbh->do(qq{DELETE FROM goods WHERE id = $good_id})
        or $app->logger->error( $app->dbh->errstr );

    return;
}

sub parse_sizes {
    my ($str) = @_;

    return [] if !$str;

    my @sizes  = ();
    my @chunks = split /,/xms, $str;

    foreach my $chunk (@chunks) {
        next if !length $chunk;

        if ( $chunk =~ /^(\d+)[-](\d+)$/xms ) {
            my ( $s1, $s2 ) = ( $1, $2 );
            for my $s ( $s1 .. $s2 ) {
                next if $s % 2 != 0;
                push @sizes, $s;
            }
        }
        elsif ( $chunk =~ /^(\d+)[.](\d+)$/xms ) {
            my ( $s1, $s2 ) = ( $1, $2 );
            if ( $s2 < $MIN_SIZE ) { $s2 = $s2 * $TEN; }
            push @sizes, $s1;
            push @sizes, $s2;
        }
        elsif ( $chunk =~ /\D(\d+)/xms ) {
            my $s = $1;
            push @sizes, $s;
        }
        else {
            push @sizes, $chunk;
        }
    }

    return \@sizes;
}

sub hide_goods {
    my (%args) = @_;

    # my $config = $args{config};
    # my $logger = $args{logger};
    my $dbh    = $args{dbh};
    my $sup_id = $args{sup_id};

    my $sel        = qq{SELECT id FROM goods WHERE sup_id = $sup_id};
    my $a_good_ids = $dbh->selectcol_arrayref($sel);

    foreach my $good_id ( @{$a_good_ids} ) {
        # $dbh->do("UPDATE goods_offers SET qty = 0 WHERE good_id = $good_id")
        $dbh->do("DELETE FROM goods_offers WHERE good_id = $good_id")
            or carp( $dbh->errstr );

        $dbh->do("DELETE FROM goods_images WHERE good_id = $good_id")
            or carp( $dbh->errstr );
    }

    $dbh->do("UPDATE goods SET changed = 1, hidden = 1 WHERE sup_id = $sup_id")
        or carp( $dbh->errstr );

    return 1;
}

sub build_good_nick {
    my (%args) = @_;

    my $sup_id = $args{sup_id};
    my $code   = $args{code};
    # my $name   = $args{name};

    # my $name_f = Util::Texter::translit(
    #     input       => $name,
    #     skip_decode => 1,
    # );
    my $code_f = Util::Texter::translit(
        input       => $code,
        skip_decode => 1,
    );

    # $name_f =~ s/[ _]+/-/g;
    # $name_f =~ s/[^\w\d\-]//g;
    # $name_f =~ s/_+/_/g;
    # $name_f =~ s/^_+//xms;
    # $name_f =~ s/_+$//xms;
    # $name_f = lc $name_f;
    # $name_f = substr $name_f, 0, $FILE_NAME_MAX_LENGTH;

    $code_f =~ s/[^\w\d\-]//g;
    $code_f =~ s/_+/_/g;
    $code_f =~ s/^_+//xms;
    $code_f =~ s/_+$//xms;
    $code_f = lc $code_f;

    # return $name_f . q{-} . $code_f . q{-} . $sup_id;
    return $code_f . q{-} . $sup_id;
}

sub build_good_p_descr {
    my (%args) = @_;

    my $cat_names   = $args{cat_names};
    my $good_name   = $args{good_name};
    my $lang_suffix = $args{lang_suffix};
    my $tpl_path    = $args{tpl_path};
    my $root_dir    = $args{root_dir};

    return Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_name => "meta-descr${lang_suffix}.txt",
        h_vars   => {
            cat_names => $cat_names,
            name      => $good_name,
        },
    );
}

sub build_img_name {
    my (%args) = @_;

    my $sup_id = $args{sup_id};
    my $code   = $args{code};
    my $num    = $args{num};
    my $ext    = $args{ext} || 'jpg';

    my $image_name = $code . q{-} . $sup_id;
    if ($num) {
        $image_name .= q{_} . $num;
    }
    $image_name .= q{.} . $ext;

    return $image_name;
}

sub save_img_path {
    my (%args) = @_;

    my $dbh         = $args{dbh};
    my $img_id      = $args{img_id};
    my $img_path_sm = $args{img_path_sm};
    my $img_path_la = $args{img_path_la};

    my $upd_tpl = <<'EOF';
        UPDATE goods_images
        SET path_sm = "%s", path_la = "%s"
        WHERE id = %u
EOF
    my $upd = sprintf $upd_tpl, $img_path_sm, $img_path_la, $img_id;
    my $rv  = $dbh->do($upd);
    if ( !$rv ) {
        carp( 'Failed image update: ' . $dbh->errstr );
        return $dbh->errstr;
    }

    return;
}

sub new_img_qty {
    my (%args) = @_;

    my $dbh = $args{dbh};

    my $sel = <<'EOF';
        SELECT COUNT(*)
        FROM goods_images
        WHERE path_sm = ""
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    my ($qty) = $sth->fetchrow_array();
    $sth->finish();

    return $qty;
}

# sub get_good_qty {
#     my ( $self, %args ) = @_;

#     my $cat_id = $args{cat_id} // 0;

#     my $sel = q{
# 		SELECT COUNT(g.id) FROM goods AS g
# 		LEFT JOIN goods_categories AS gc ON g.id = gc.good_id
# 		WHERE gc.cat_id = ?
# 		AND g.hidden = 0
# 	};
#     my $sth = $app->dbh->prepare($sel);
#     my $rv  = $sth->execute($cat_id);
#     if ( !$rv ) {
#         $app->logger->error( $app->dbh->errstr() );
#         croak( $app->dbh->errstr() );
#     }

#     my ($qty) = $sth->fetchrow_array();
#     $sth->finish();

#     return $qty;
# }

1;
