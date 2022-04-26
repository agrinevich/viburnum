package App::Admin::Lang::Add;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $name    = $o_params->{name}    // q{};
    my $nick    = $o_params->{nick}    // q{};
    my $isocode = $o_params->{isocode} // q{};

    my $sel = 'SELECT LAST_INSERT_ID()';
    my $ins = <<'EOF';
        INSERT INTO langs
            (name, nick, isocode)
        VALUES
            (?, ?, ?)
EOF

    my $sth  = $app->dbh->prepare($ins);
    my $sth2 = $app->dbh->prepare($sel);

    $sth->execute( $name, $nick, $isocode );
    $sth2->execute();
    my ($id) = $sth2->fetchrow_array();

    $sth->finish();
    $sth2->finish();

    _copy_page_marks(
        dbh     => $app->dbh,
        lang_id => $id,
    );

    _copy_notes_versions(
        dbh     => $app->dbh,
        lang_id => $id,
    );

    _copy_goods_versions(
        dbh     => $app->dbh,
        lang_id => $id,
    );

    #
    # TODO: _copy_tpl_versions
    #

    return {
        url => $app->config->{site}->{host} . '/admin/lang',
    };
}

sub _copy_page_marks {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $lang_id = $args{lang_id};

    my $ins = <<'EOF3';
        INSERT INTO page_marks
            (page_id, lang_id, name, value)
        VALUES
            (?, ?, ?, ?)
EOF3
    my $sth2 = $dbh->prepare($ins);

    my $sel = <<'EOF2';
        SELECT page_id, name, value
        FROM page_marks
        WHERE lang_id = 1
EOF2
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $page_id, $name, $value ) = $sth->fetchrow_array() ) {
        $sth2->execute( $page_id, $lang_id, $name, $value );
    }
    $sth->finish();
    $sth2->finish();

    return;
}

sub _copy_notes_versions {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $lang_id = $args{lang_id};

    my $ins = <<'EOF3';
        INSERT INTO notes_versions
            (note_id, lang_id, name, p_title, p_descr, descr)
        VALUES
            (?, ?, ?, ?, ?, ?)
EOF3
    my $sth2 = $dbh->prepare($ins);

    my $sel = <<'EOF2';
        SELECT note_id, name, p_title, p_descr, descr
        FROM notes_versions
        WHERE lang_id = 1
EOF2
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $note_id, $name, $p_title, $p_descr, $descr ) = $sth->fetchrow_array() ) {
        $sth2->execute( $note_id, $lang_id, $name, $p_title, $p_descr, $descr );
    }
    $sth->finish();
    $sth2->finish();

    return;
}

sub _copy_goods_versions {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $lang_id = $args{lang_id};

    my $ins = <<'EOF3';
        INSERT INTO goods_versions
            (good_id, lang_id, name, p_title, p_descr, descr)
        VALUES
            (?, ?, ?, ?, ?, ?)
EOF3
    my $sth2 = $dbh->prepare($ins);

    my $sel = <<'EOF2';
        SELECT good_id, name, p_title, p_descr, descr
        FROM goods_versions
        WHERE lang_id = 1
EOF2
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $good_id, $name, $p_title, $p_descr, $descr ) = $sth->fetchrow_array() ) {
        $sth2->execute( $good_id, $lang_id, $name, $p_title, $p_descr, $descr );
    }
    $sth->finish();
    $sth2->finish();

    return;
}

1;
