package Asession;

use Moo;
use English qw(-no_match_vars);

use Util::Crypto;

has 'dbh' => (
    is       => 'ro',
    required => 1,
);

has 'domain' => (
    is       => 'ro',
    required => 1,
);

has 'cookie_ttl' => (
    is       => 'ro',
    required => 1,
);

has 'otp_ttl' => (
    is       => 'ro',
    required => 1,
);

has 'is_secure' => (
    is       => 'ro',
    required => 1,
); # require HTTPS

has 'sess_id' => (
    is => 'rw',
);

our $VERSION = '1.1';

sub data {
    my ($self) = @_;

    my $sess_id = $self->sess_id();

    my $sel = <<'EOF';
        SELECT
            user_id,
            otp_digits,
            otp_sha1hex,
            email,
            phone,
            dest_area_id,
            dest_city_id,
            dest_wh_id,
            dest_id
        FROM sess
        WHERE id = ?
EOF
    my $sth = $self->dbh->prepare($sel);
    $sth->execute($sess_id);
    my (
        $user_id,
        $otp_digits,
        $otp,
        $email,
        $phone,
        $dest_area_id,
        $dest_city_id,
        $dest_wh_id,
        $dest_id
    ) = $sth->fetchrow_array();
    $sth->finish();

    return {
        sess_id      => $sess_id,
        user_id      => $user_id,
        otp_digits   => $otp_digits,
        otp          => $otp,
        email        => $email,
        phone        => $phone,
        dest_area_id => $dest_area_id,
        dest_city_id => $dest_city_id,
        dest_wh_id   => $dest_wh_id,
        dest_id      => $dest_id,
    };
}

sub handle {
    my ( $self, %args ) = @_;

    my $h_cookies = $args{h_cookies};
    my $ip        = $args{ip} // q{};
    my $ua        = $args{ua} // q{};

    if ( !$h_cookies->{sess} ) {
        $self->_create(
            ip => $ip,
            ua => $ua,
        );

        return {
            value   => $self->sess_id,
            path    => q{/},
            domain  => q{.} . $self->domain,
            expires => time + $self->cookie_ttl,
            secure  => $self->is_secure,
        };
    }

    $self->_delete_expired();

    my $sel = q{SELECT COUNT(*) FROM sess WHERE id = ?};
    my $sth = $self->dbh->prepare($sel);
    $sth->execute( $h_cookies->{sess} );
    my ($sess_exists) = $sth->fetchrow_array();
    $sth->finish();

    if ($sess_exists) { $self->_update( sess_id => $h_cookies->{sess} ); }
    else              { $self->_create(); }

    return {
        value   => $self->sess_id,
        path    => q{/},
        domain  => q{.} . $self->domain,
        expires => time + $self->cookie_ttl,
        secure  => $self->is_secure,
    };
}

sub _update {
    my ( $self, %args ) = @_;

    my $sess_id = $args{sess_id};

    $self->dbh->do("UPDATE sess SET updated_at = NOW() WHERE id = \"$sess_id\"");
    $self->sess_id($sess_id);

    return 1;
}

sub _create {
    my ( $self, %args ) = @_;

    my $ip = $args{ip};
    my $ua = $args{ua};

    my $sess_id = Util::Crypto::get_sha1_hex(
        str => rand . $PID . {} . time,
    );

    $self->dbh->do("INSERT INTO sess (id, ip, ua) VALUES (\"$sess_id\", \"$ip\", \"$ua\")");
    $self->sess_id($sess_id);

    return 1;
}

sub _delete_expired {
    my ($self) = @_;

    my $cookie_ttl = $self->cookie_ttl;
    my $otp_ttl    = $self->otp_ttl;

    # expired email auth attempts
    my $upd_tpl = <<'EOF';
        UPDATE sess SET
            email = "",
            otp_sha1hex = ""
        WHERE otp_sha1hex <> ""
        AND UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(updated_at) > %s
EOF
    my $upd = sprintf $upd_tpl, $otp_ttl;
    $self->dbh->do($upd);

    # expired phone auth attempts
    my $upd2_tpl = <<'EOF';
        UPDATE sess SET
            phone = "",
            otp_digits = 0
        WHERE otp_digits > 0
        AND UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(updated_at) > %s
EOF
    my $upd2 = sprintf $upd2_tpl, $otp_ttl;
    $self->dbh->do($upd2);

    # clean shopping carts for expired sessions
    my $sel = <<'EOF';
        SELECT id
        FROM sess
        WHERE UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(updated_at) > ?
EOF
    my $sth2 = $self->dbh->prepare($sel);
    $sth2->execute($cookie_ttl);
    while ( my ($sid) = $sth2->fetchrow_array() ) {
        $self->dbh->do(qq{DELETE FROM sess_cart WHERE sess_id = "$sid"});
    }
    $sth2->finish();

    # clean expired sessions
    my $del_tpl = <<'EOF';
        DELETE FROM sess
        WHERE UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(updated_at) > %s
EOF
    my $del = sprintf $del_tpl, $cookie_ttl;
    $self->dbh->do($del);

    return;
}

#
# user can have 2 separate sessions on different devices
# so we check only by phone (without sess_id)
#
sub is_phone_pending {
    my ( $self, $phone ) = @_;

    return if !$phone;

    my $sel = q{SELECT COUNT(id) FROM sess WHERE phone = ? AND otp_digits > 0};
    my $sth = $self->dbh->prepare($sel);
    $sth->execute($phone);
    my ($is_pending) = $sth->fetchrow_array();
    $sth->finish();

    return $is_pending;
}

sub check_otp {
    my ( $self, $phone, $otp, $attempts_max ) = @_;

    $self->dbh->do("UPDATE sess SET otp_attempts = otp_attempts + 1 WHERE phone = \"$phone\"");

    my $sel = q{SELECT otp_attempts FROM sess WHERE phone = ?};
    my $sth = $self->dbh->prepare($sel);
    $sth->execute($phone);
    my ($attempts) = $sth->fetchrow_array();
    $sth->finish();

    if ( $attempts > $attempts_max ) {
        return ( 0, $attempts );
    }

    my $sel2 = q{SELECT id FROM sess WHERE phone = ? AND otp_digits = ?};
    my $sth2 = $self->dbh->prepare($sel2);
    $sth2->execute( $phone, $otp );
    my ($orig_sess_id) = $sth2->fetchrow_array();
    $sth2->finish();

    if ( !$orig_sess_id ) {
        return ( 0, $attempts );
    }

    $self->dbh->do("UPDATE sess SET otp_digits = 0 WHERE id = \"$orig_sess_id\"");

    my $cur_sess_id = $self->sess_id;
    if ( $orig_sess_id ne $cur_sess_id ) {
        $self->dbh->do(
            "UPDATE sess_cart SET sess_id = \"$orig_sess_id\" WHERE sess_id = \"$cur_sess_id\"");
        $self->sess_id($orig_sess_id);
    }

    return ( $orig_sess_id, $attempts );
}

sub set_user {
    my ( $self, $user_id ) = @_;

    return if !$user_id;

    my $sess_id = $self->sess_id;
    $self->dbh->do("UPDATE sess SET user_id = $user_id WHERE id = \"$sess_id\"");

    return;
}

1;
