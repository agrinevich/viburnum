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

sub handle {
    my ( $self, %args ) = @_;

    my $h_cookies = $args{h_cookies};
    my $ip        = $args{ip} // q{};
    my $ua        = $args{ua} // q{};

    if ( !$h_cookies->{sess} ) {
        #
        # ? in some cases we need to sync session on another device (see Signin.pm)
        #

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
    my ($sess_ok) = $sth->fetchrow_array();
    $sth->finish();

    if ($sess_ok) { $self->_update( sess_id => $h_cookies->{sess} ); }
    else          { $self->_create(); }

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

    # expired auth attempts
    my $upd_tpl = <<'EOF';
        UPDATE sess SET email = "", otp_sha1hex = ""
        WHERE otp_sha1hex <> ""
        AND UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(updated_at) > %s
EOF
    my $upd = sprintf $upd_tpl, $otp_ttl;
    $self->dbh->do($upd);

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

1;
