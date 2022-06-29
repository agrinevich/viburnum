package Util::Cart;

use strict;
use warnings;

our $VERSION = '1.1';

sub get_goods {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $sess_id = $args{sess_id};
    my $lang_id = $args{lang_id};

    my @result = ();

    my $sel = <<'EOF';
        SELECT sc.item_id, sc.item_qty, sc.item_price, nv.name
        FROM sess_cart AS sc
        LEFT JOIN notes_versions AS nv
            ON sc.item_id = nv.note_id
        WHERE sc.sess_id = ?
        AND nv.lang_id = ?
        ORDER BY nv.name ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $sess_id, $lang_id );
    while ( my ( $id, $qty, $price, $name ) = $sth->fetchrow_array() ) {
        push @result, {
            id    => $id,
            qty   => $qty,
            price => $price,
            name  => $name,
        };
    }
    $sth->finish();

    return \@result;
}

1;
