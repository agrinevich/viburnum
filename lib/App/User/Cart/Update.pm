package App::User::Cart::Update;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} // q{};
    my $item_id   = $o_params->{id} || 0;
    my $item_qty  = $o_params->{qty} || 0;

    if ( !$item_id ) {
        return {
            url => $app->config->{site}->{host} . '/user/say?m=error&l=' . $lang_nick,
        };
    }

    my $sess_id = $app->session->{sess_id};

    my $upd = <<'EOF';
        UPDATE sess_cart SET
            item_qty = ?
        WHERE sess_id = ?
        AND item_id = ?
EOF
    my $sth2 = $app->dbh->prepare($upd);
    $sth2->execute( $item_qty, $sess_id, $item_id );

    return {
        url => $app->config->{site}->{host} . '/user/cart?l=' . $lang_nick,
    };
}

1;
