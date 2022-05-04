package App::Admin::Cat::Update;

use strict;
use warnings;

use Util::Tree;
use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $id        = $o_params->{id} || 0;
    my $parent_id = $o_params->{parent_id} || 0;
    my $priority  = $o_params->{priority} || 0;
    my $hidden    = $o_params->{hidden} || 0;
    my $navi_on   = $o_params->{navi_on} || 0;
    my $mode      = $o_params->{mode} || 0;
    my $name      = $o_params->{name} // q{};
    my $nick      = $o_params->{nick} // q{};

    my $root_dir  = $app->root_dir;
    my $html_path = $app->config->{data}->{html_path};

    if ( $parent_id == $id ) {
        return {
            url => $app->config->{site}->{host} . q{/admin/cat/edit?id=} . $id,
        };
    }

    if ( $parent_id > 0 && !$nick ) { $nick = $id; }

    my $h_page = Util::Tree::get_page(
        dbh     => $app->dbh,
        page_id => $id,
    );
    my $old_nick   = $h_page->{nick};
    my $old_parent = $h_page->{parent_id};
    my $old_path   = Util::Tree::page_path(
        dbh     => $app->dbh,
        page_id => $id,
    );
    my $old_dir = $root_dir . $html_path . $old_path;

    if ( $nick ne $old_nick || $parent_id != $old_parent ) {
        # check if nick is unique after nick or parent_id was changed
        my $nick_is_unique = Util::Tree::is_nick_unique(
            dbh       => $app->dbh,
            id        => $id,
            parent_id => $parent_id,
            nick      => $nick,
        );
        if ( !$nick_is_unique ) {
            return {
                url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $id . '&msg=error',
            };
        }
    }

    my $upd = <<'EOF';
        UPDATE pages SET
            changed   = 1,
            parent_id = ?,
            priority  = ?,
            hidden    = ?,
            navi_on    = ?,
            mode       = ?,
            name      = ?,
            nick      = ?
        WHERE id = ?
EOF
    my $sth = $app->dbh->prepare($upd);
    $sth->execute(
        $parent_id,
        $priority,
        $hidden,
        $navi_on,
        $mode,
        $name,
        $nick,
        $id
    );

    if ( $nick ne $old_nick || $parent_id != $old_parent ) {
        # move existing files from old to new dir
        my $new_path = Util::Tree::page_path(
            dbh     => $app->dbh,
            page_id => $id,
        );
        my $new_dir = $root_dir . $html_path . $new_path;
        Util::Files::move_dir(
            src_dir => $old_dir,
            dst_dir => $new_dir,
        );

        # we need it to build navi during pages generation
        Util::Tree::update_child_qty( dbh => $app->dbh );
    }

    return {
        url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $id . '&msg=success',
    };
}

1;
