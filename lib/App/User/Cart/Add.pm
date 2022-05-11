package App::User::Cart::Add;

use strict;
use warnings;

use Util::Langs;
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
            url => $app->config->{site}->{host} . '/user/cart?l=' . $lang_nick,
        };
    }

    # TODO: is_ip_banned
    # my $ip              = $o_request->address() // q{};
    # my $ua              = $o_request->user_agent() // q{};

    my $sess_id = $app->session->{sess_id};

    my $h_note = Util::Notes::get_note(
        dbh => $app->dbh,
        id  => $item_id,
    );

    my $h_lang = Util::Langs::get_lang(
        dbh       => $app->dbh,
        lang_nick => $lang_nick,
    );

    my $ins = <<'EOF';
        INSERT INTO sess_cart
        (sess_id, item_id, item_qty, item_price)
        VALUES
        (?, ?, ?, ?)
EOF
    my $sth = $app->dbh->prepare($ins);
    $sth->execute( $sess_id, $item_id, 1, $h_note->{price} );

    return {
        url => $app->config->{site}->{host} . '/user/cart?l=' . $lang_nick,
    };
}

1;
