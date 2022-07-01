package Util::Users;

use strict;
use warnings;

our $VERSION = '1.1';

sub get_user {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $u_id    = $args{id};
    my $u_phone = $args{phone};

    my ( $id, $name, $email, $address );

    if ($u_id) {
        my $sel = 'SELECT name, email, address FROM users WHERE id = ?';
        my $sth = $dbh->prepare($sel);
        $sth->execute($u_id);
        ( $name, $email, $address ) = $sth->fetchrow_array();
        $sth->finish();

        $id = $u_id;
    }
    elsif ($u_phone) {
        my $sel = <<'EOF';
        SELECT u.id, u.name, u.email, u.address
        FROM users AS u
        LEFT JOIN users_phones AS up
        ON u.id = up.user_id
        WHERE up.phone = ?
EOF
        my $sth = $dbh->prepare($sel);
        $sth->execute($u_phone);
        ( $id, $name, $email, $address ) = $sth->fetchrow_array();
        $sth->finish();
    }
    else {
        return;
    }

    return {
        id      => $id,
        name    => $name,
        email   => $email,
        address => $address,
    };
}

sub add_user {
    my (%args) = @_;

    my $dbh   = $args{dbh};
    my $phone = $args{phone};

    $dbh->do('INSERT INTO users (name) VALUES ("")');

    my $sel = 'SELECT LAST_INSERT_ID()';
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    my ($id) = $sth->fetchrow_array();
    $sth->finish();

    $dbh->do("INSERT INTO users_phones (user_id, phone) VALUES ($id, \"$phone\")");

    return;
}

sub update_user {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $id      = $args{id};
    my $name    = $args{name};
    my $email   = $args{email};
    my $address = $args{address};

    my $upd = <<'EOF';
        UPDATE users SET
            name = ?,
            email = ?,
            address = ?
        WHERE id= ?
EOF
    my $sth = $dbh->prepare($upd);
    $sth->execute( $name, $email, $address, $id );

    return;
}

1;
