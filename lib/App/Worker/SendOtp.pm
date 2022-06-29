package App::Worker::SendOtp;

use strict;
use warnings;

use parent qw( TheSchwartz::Worker );
use TheSchwartz::Job;

use Try::Tiny;
use Data::Dumper;
use English qw(-no_match_vars);
use Carp qw(croak carp);

use Util::Config;
use Util::DB;
use Util::HTTP;

our $VERSION = '1.1';

sub work {
    my ( undef, $job ) = @_;

    my %args = @{ $job->arg };

    my $root_dir  = $args{root_dir};
    my $conf_file = $args{conf_file};
    my $lang_nick = $args{lang_nick};
    my $phone     = $args{phone};
    my $sess_id   = $args{sess_id};

    my $config = Util::Config::get_config(
        file => $root_dir . q{/} . $conf_file,
    );

    my $dbh = Util::DB::get_dbh(
        db_name => $config->{mysql}->{db_name},
        db_user => $config->{mysql}->{user},
        db_pass => $config->{mysql}->{pass},
    );

    my $otp = _create_otp(
        dbh     => $dbh,
        max     => 9999,
        phone   => $phone,
        sess_id => $sess_id,
    );
    if ( !$otp ) {
        carp('Failed to SendOtp: OTP creation error');
        $job->failed('Failed to SendOtp: OTP creation error');
        return;
    }

    my $h_params = {
        login  => $config->{sms}->{login},
        psw    => $config->{sms}->{passw},
        phones => $phone,
        sender => 'Avalanche',
        mes    => $otp,
    };

    my $is_ok = try {
        my $h_response = Util::HTTP::request(
            api_url => $config->{sms}->{gate},
            params  => $h_params,
        );
        if ( $h_response->{content}->{result} eq 'error' ) {
            # carp( 'response: ' . Dumper($h_response) );
            carp( 'error: ' . $h_response->{content}->{error_message} );
            $job->failed('Failed to SendOtp');
            return;
        }

        #
        # TODO: save sms id
        #
        my $sms_id = $h_response->{content}->{id};

        $job->completed();
        return 1;
    }
    catch {
        carp("Failed to SendOtp: $_");
        $job->failed('Failed to SendOtp');
        return;
    };

    return;
}

sub _create_otp {
    my (%args) = @_;

    my $max     = $args{max};
    my $dbh     = $args{dbh};
    my $phone   = $args{phone};
    my $sess_id = $args{sess_id};

    return if !$max;

    my $otp = int rand $max;

    my $sel = q{SELECT COUNT(id) FROM sess WHERE otp_digits = ?};
    my $sth = $dbh->prepare($sel);
    $sth->execute($otp);
    my ($is_duplicated) = $sth->fetchrow_array();
    $sth->finish();

    if ( $is_duplicated || $otp == 0 ) {
        $otp = _create_otp(
            dbh     => $dbh,
            max     => $max - 1,
            sess_id => $sess_id,
        );
    }

    if ( $otp > 0 ) {
        $dbh->do(
            "UPDATE sess SET otp_digits = $otp, otp_attempts = 0, phone = \"$phone\" WHERE id = \"$sess_id\""
        );
    }

    return $otp;
}

1;
