package App::Admin::Cat::Markupd;

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
    my $id      = $o_params->{id}      || 0;
    my $copy    = $o_params->{copy}    || 0;
    my $name  = $o_params->{name}  // q{};
    my $value = $o_params->{value} // q{};

    if ($copy) {
        my @page_ids;
        my $sel = "SELECT id FROM pages WHERE id <> $page_id";
        my $sth = $app->dbh->prepare($sel);
        $sth->execute();
        while ( my ($p_id) = $sth->fetchrow_array() ) {
            push @page_ids, $p_id;
        }
        $sth->finish();

        my $upd = <<'EOF2';
        REPLACE INTO page_marks
        (page_id, lang_id, name, value)
        VALUES
        (?, ?, ?, ?)
EOF2
        my $sth2 = $app->dbh->prepare($upd);
        foreach my $p_id (@page_ids) {
            $sth2->execute( $p_id, $lang_id, $name, $value );
        }
        $sth2->finish();

        $app->dbh->do('UPDATE pages SET changed = 1');
    }

    my $upd = <<'EOF';
        UPDATE page_marks SET
            name = ?,
            value = ?
        WHERE id = ?
EOF
    my $sth = $app->dbh->prepare($upd);
    $sth->execute( $name, $value, $id );

    $app->dbh->do("UPDATE pages SET changed = 1 WHERE id = $page_id");

    return {
              url => $app->config->{site}->{host}
            . '/admin/cat/markedit?id='
            . $id
            . q{&page_id=}
            . $page_id,
    };
}

1;
