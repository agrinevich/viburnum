package App::Admin;

use Moo;
extends 'App';
use Const::Fast;
use Plack::Request;
use Encode qw(decode encode);

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
        path_info => $o_request->path_info(),
    );

    if ( !$class_name ) {
        my $o_response = $o_request->new_response($_RESPONSE_404);
        $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );
        $o_response->body(q{404: not found});
        return $o_response;
    }

    $self->dbh->do( q{USE } . $self->config->{mysql}->{db_name} );

    my $h_result = $class_name->doit(
        app       => $self,
        o_request => $o_request,
    );

    if ( $h_result->{url} ) {
        my $o_response = $o_request->new_response($_RESPONSE_REDIR);
        $o_response->redirect( $h_result->{url} );
        return $o_response;
    }

    my $o_response = $o_request->new_response($_RESPONSE_OK);
    $o_response->header( 'Content-Type' => 'text/html', charset => 'Utf-8' );
    my $octets = encode( 'UTF-8', $h_result->{body} );
    $o_response->body($octets);
    return $o_response;
}

1;
