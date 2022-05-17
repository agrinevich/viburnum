package App::Admin::Note::Update;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $id   = $o_params->{id}   || 0;
    my $prio = $o_params->{prio} || 0;
    my $nick = $o_params->{nick};
    my $price = $o_params->{price};

    $price =~ s/[,]/[.]/g;
    $price =~ s/[^\d.]//g;
    if ( $price !~ /[\d.]/ ) {
        $price = 0;
    }

    #
    # TODO: get old nick before update and
    # delete old page if nick is changed
    #

    my $upd = <<'EOF';
        UPDATE notes SET
            nick  = ?,
            prio  = ?,
            price = ?
        WHERE id = ?
EOF
    my $sth = $app->dbh->prepare($upd);
    $sth->execute(
        $nick,
        $prio,
        $price,
        $id
    );

    return {
        url => $app->config->{site}->{host} . '/admin/note/edit?id=' . $id,
    };
}

1;
