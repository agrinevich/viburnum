package App::User::Cart::Add;

use strict;
use warnings;

use Util::Notes;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} // q{};
    my $item_id   = $o_params->{id} || 0;

    if ( !$item_id ) {
        return {
            url => $app->config->{site}->{host} . '/user/say?m=error&l=' . $lang_nick,
        };
    }

    # TODO: is_ip_banned
    # my $ip              = $o_request->address() // q{};
    # my $ua              = $o_request->user_agent() // q{};

    my $sess_id = $app->session->{sess_id};

    my $sel = <<'EOF';
        SELECT COUNT(sess_id)
        FROM sess_cart
        WHERE sess_id = ?
        AND item_id = ?
EOF
    my $sth = $app->dbh->prepare($sel);
    $sth->execute( $sess_id, $item_id );
    my ($item_in_cart) = $sth->fetchrow_array();
    $sth->finish();

    if ($item_in_cart) {
        my $upd = <<'EOF';
            UPDATE sess_cart SET
                item_qty = item_qty + 1
            WHERE sess_id = ?
            AND item_id = ?
EOF
        my $sth2 = $app->dbh->prepare($upd);
        $sth2->execute( $sess_id, $item_id );
    }
    else {
        my $h_note = Util::Notes::get_note(
            dbh => $app->dbh,
            id  => $item_id,
        );

        my $ins = <<'EOF';
            INSERT INTO sess_cart
            (sess_id, item_id, item_qty, item_price)
            VALUES
            (?, ?, ?, ?)
EOF
        my $sth3 = $app->dbh->prepare($ins);
        $sth3->execute( $sess_id, $item_id, 1, $h_note->{price} );
    }

    return {
        url => $app->config->{site}->{host} . '/user/cart?l=' . $lang_nick,
    };
}

1;
