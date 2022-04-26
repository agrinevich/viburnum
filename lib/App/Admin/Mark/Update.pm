package App::Admin::Mark::Update;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $id    = $o_params->{id} || 0;
    my $name  = $o_params->{name} // q{};
    my $value = $o_params->{value} // q{};

    my $upd = <<'EOF';
        UPDATE global_marks SET
            name = ?,
            value = ?
        WHERE id = ?
EOF
    my $sth = $app->dbh->prepare($upd);
    $sth->execute( $name, $value, $id );

    $app->dbh->do('UPDATE pages SET changed = 1');

    return {
        url => $app->config->{site}->{host} . '/admin/mark/edit?id=' . $id,
    };
}

1;
