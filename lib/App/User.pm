package App::User;

use Moo;
extends 'App';
use Const::Fast;
use Plack::Request;
use Encode qw(decode encode);

use Asession;

has 'session' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return Asession->new(
            dbh        => $self->dbh,
            domain     => $self->config->{site}->{domain},
            cookie_ttl => $self->config->{session}->{cookie_ttl},
            otp_ttl    => $self->config->{session}->{otp_ttl},
            is_secure  => $self->config->{session}->{is_secure},
        );
    },
);

our $VERSION = '1.1';

const my $_RESPONSE_OK    => 200;
const my $_RESPONSE_REDIR => 302;
const my $_RESPONSE_404   => 404;

sub run {
    my ( $self, $env ) = @_;

    # init lazy: sequence is important
    my $conf   = $self->config();
    my $logger = $self->logger();

    my $o_request  = Plack::Request->new($env);
    my $o_response = $self->_get_response($o_request);

    return $o_response;
}

sub _get_response {
    my ( $self, $o_request ) = @_;

    my $class_name = $self->require_class(
        path_info      => $o_request->path_info(),
        a_path_default => [ 'user', 'say' ],
    );

    if ( !$class_name ) {
        my $o_response = $o_request->new_response($_RESPONSE_404);
        $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );
        $o_response->body(q{404: not found});
        return $o_response;
    }

    my $ua = $o_request->user_agent() // q{};
    if ( $ua eq 'AdsBot-Google' ) {
        my $o_response = $o_request->new_response($_RESPONSE_OK);
        $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );

        my $body   = 'hello bot';
        my $octets = encode( 'UTF-8', $body );
        $o_response->body($octets);
        return $o_response;
    }

    # widget does not handle cookies because of SSI call !
    # my $sess_id = $o_request->cookies()->{sess};
    # if ( $class_name eq 'App::User::Widget' && !$sess_id ) {
    #     my $h_result = App::User::Widget->new(
    #         app => $self,
    #     )->doit( $o_request, 'no_session' );

    #     my $o_response = $o_request->new_response($_RESPONSE_OK);
    #     $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );

    #     my $body   = $h_result->{body} // q{-};
    #     my $octets = encode( 'UTF-8', $body );
    #     $o_response->body($octets);

    #     return $o_response;
    # }

    # if ( !$self->dbh->ping() ) {
    #     $self->db_reconnect();
    # }
    $self->dbh->do( q{USE } . $self->config->{mysql}->{db_name} );

    my $h_sess = $self->session->handle(
        h_cookies => $o_request->cookies(),
        ip        => $o_request->address(),
        ua        => $o_request->user_agent(),
    );

    my $h_result = $class_name->doit(
        app       => $self,
        o_request => $o_request,
    );

    if ( exists $h_result->{sess} ) {
        # if session params was modified by class
        $h_sess = $h_result->{sess};
    }

    my $o_response;
    my $url = $h_result->{url} // q{};
    if ($url) {
        $o_response = $o_request->new_response($_RESPONSE_REDIR);
        $o_response->cookies->{sess} = $h_sess;
        $o_response->redirect($url);
    }
    else {
        $o_response = $o_request->new_response($_RESPONSE_OK);
        $o_response->cookies->{sess} = $h_sess;
        $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );

        my $body   = $h_result->{body} // q{Empty answer};
        my $octets = encode( 'UTF-8', $body );
        $o_response->body($octets);
    }

    return $o_response;
}

1;
