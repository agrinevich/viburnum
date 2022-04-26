package App::Admin::Cat::Markadd;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $page_id = $o_params->{page_id} || 0;
    my $lang_id = $o_params->{lang_id} || 0;
    my $name  = $o_params->{name}  // q{};
    my $value = $o_params->{value} // q{};

    my $ins = <<'EOF';
        INSERT INTO page_marks
            (page_id, lang_id, name, value)
        VALUES
            (?, ?, ?, ?)
EOF
    my $sth = $app->dbh->prepare($ins);
    $sth->execute( $page_id, $lang_id, $name, $value );

    return {
        url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $page_id,
    };
}

1;
