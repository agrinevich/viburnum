package App::User::Who::Checkotp;

use strict;
use warnings;

use Const::Fast;

use Util::Users;

our $VERSION = '1.1';

const my $ATTEMPTS_MAX => 5;

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} || q{};
    my $ret_url   = $o_params->{ret} || q{};
    my $phone     = $o_params->{phone} || q{};
    my $otp       = $o_params->{otp} || q{};

    #
    # TODO: is_ip_banned (in User app! like middleware)
    #

    my ( $orig_sess_id, $attempts ) = $app->session->check_otp( $phone, $otp, $ATTEMPTS_MAX );
    if ( !$orig_sess_id ) {
        return {
                  url => $app->config->{site}->{host}
                . '/user/who/pending?phone='
                . $phone
                . '&attempts='
                . $attempts,
        };
    }

    my $h_user = Util::Users::get_user(
        dbh   => $app->dbh,
        phone => $phone,
    );
    if ( !$h_user->{id} ) {
        Util::Users::add_user(
            dbh   => $app->dbh,
            phone => $phone,
        );
    }

    $app->session->set_user( $h_user->{id} );

    # TODO: update signin datetime - users, users_phones

    return {
        url  => $app->config->{site}->{host} . '/user/cart/fill',
        sess => {
            value   => $app->session->sess_id,
            path    => q{/},
            domain  => q{.} . $app->session->domain,
            expires => time + $app->session->cookie_ttl,
            secure  => $app->session->is_secure,
        },
    };
}

1;
