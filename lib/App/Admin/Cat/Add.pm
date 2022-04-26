package App::Admin::Cat::Add;

use strict;
use warnings;

use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $parent_id = $o_params->{parent_id} || 0;
    my $name      = $o_params->{name} // q{};
    my $nick      = $o_params->{nick} // q{};

    if ( !$nick ) {
        return {
            url => $app->config->{site}->{host} . '/admin/cat',
        };
    }

    #
    # TODO: check nick is unique for this parent!
    #
    # my $nick_is_unique = Util::Tree::is_nick_unique(
    #     dbh       => $app->dbh,
    #     id        => $id,
    #     parent_id => $parent_id,
    #     nick      => $nick,
    # );
    # if ( !$nick_is_unique ) {
    #     return {
    #         url => $app->config->{site}->{host} . q{/admin/cat/edit?id=} . $id,
    #     };
    # }

    my $h_parent = _get_properties( $app->dbh, $parent_id );
    my $hidden   = $h_parent->{hidden};
    my $mode     = $h_parent->{mode};

    my $ins = <<'EOF';
		INSERT INTO pages
		(parent_id, hidden, mode, name, nick)
		VALUES
		(?, ?, ?, ?, ?)
EOF
    my $sel = 'SELECT LAST_INSERT_ID()';

    my $sth  = $app->dbh->prepare($ins);
    my $sth2 = $app->dbh->prepare($sel);

    # $app->dbh->do('LOCK TABLES pages WRITE');
    $sth->execute( $parent_id, $hidden, $mode, $name, $nick );
    $sth2->execute();
    my ($id) = $sth2->fetchrow_array();
    # $app->dbh->do('UNLOCK TABLES');

    $sth->finish();
    $sth2->finish();

    Util::Tree::update_child_qty( dbh => $app->dbh );

    _copy_marks( $app, $parent_id, $id );

    return {
        url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $id,
    };
}

sub _get_properties {
    my ( $dbh, $id ) = @_;

    my $sel = q{SELECT parent_id, priority, hidden, mode, name, nick FROM pages WHERE id = ?};
    my $sth = $dbh->prepare($sel);
    $sth->execute($id);
    my (
        $parent_id,
        $priority,
        $hidden,
        $mode,
        $name,
        $nick
    ) = $sth->fetchrow_array();
    $sth->finish();

    return if !defined $name;

    return {
        id        => $id,
        parent_id => $parent_id,
        priority  => $priority,
        hidden    => $hidden,
        mode      => $mode,
        name      => $name,
        nick      => $nick,
    };
}

sub _copy_marks {
    my ( $app, $parent_id, $new_id ) = @_;

    my $ins = <<'EOF1';
		INSERT INTO page_marks (page_id, lang_id, name, value)
		VALUES (?, ?, ?, ?)
EOF1
    my $sth2 = $app->dbh->prepare($ins);

    my $sel = <<'EOF2';
		SELECT lang_id, name, value
		FROM page_marks
		WHERE page_id = ?
		ORDER BY lang_id ASC, name ASC
EOF2
    my $sth = $app->dbh->prepare($sel);
    $sth->execute($parent_id);
    while ( my ( $lang_id, $name, $value ) = $sth->fetchrow_array() ) {
        $sth2->execute( $new_id, $lang_id, $name, $value );
    }

    $sth->finish();
    $sth2->finish();

    return;
}

1;
