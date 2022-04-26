package App::Admin::Mark::Add;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $name  = $o_params->{name}  // q{};
    my $value = $o_params->{value} // q{};

    my $ins = <<'EOF';
        INSERT INTO global_marks
            (name, value)
        VALUES
            (?, ?)
EOF
    my $sth = $app->dbh->prepare($ins);
    $sth->execute( $name, $value );

    return {
        url => $app->config->{site}->{host} . '/admin/mark',
    };
}

1;
