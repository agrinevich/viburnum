package Util::Tree;

use strict;
use warnings;

use Const::Fast;

use Util::Renderer;

our $VERSION = '1.1';

const my %MODE => (
    0 => 'Page',
    1 => 'Shop',
    2 => 'Notes',
);

const my %MODE_LINK => (
    0 => q{},
    1 => q{},
    2 => ' &bull; <a href="/admin/note?page_id=%u" target="_blank">notes</a>',
);

# my %CHAIN    = (); # cache
# my %PAGEPATH = (); # cache

sub is_nick_unique {
    my (%args) = @_;

    my $dbh        = $args{dbh};
    my $id         = $args{id};
    my $parent_id  = $args{parent_id};
    my $nick2check = $args{nick};

    my $sel = 'SELECT nick FROM pages WHERE parent_id = ? AND id <> ?';
    my $sth = $dbh->prepare($sel);
    $sth->execute( $parent_id, $id );
    while ( my ($nick) = $sth->fetchrow_array() ) {
        return 0 if $nick eq $nick2check;
    }
    $sth->finish();

    return 1;
}

sub page_path {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $page_id = $args{page_id};

    # return $PAGEPATH{$page_id} if exists $PAGEPATH{$page_id};

    my $sel = 'SELECT parent_id, nick FROM pages WHERE id = ?';
    my $sth = $dbh->prepare($sel);
    $sth->execute($page_id);
    my ( $parent_id, $nick ) = $sth->fetchrow_array();
    $sth->finish();

    my $page_path = $nick ? q{/} . $nick : q{};

    if ( $parent_id > 0 ) {
        $page_path = page_path(
            dbh     => $dbh,
            page_id => $parent_id,
        ) . $page_path;
    }

    # $PAGEPATH{$page_id} = $page_path;

    return $page_path;
}

sub get_chain {
    my ( $h_args, $a_chain ) = @_;

    my $dbh     = $h_args->{dbh};
    my $lang_id = $h_args->{lang_id};
    my $id      = $h_args->{id};
    $a_chain //= [];

    # my $key = $id . q{_} . $lang_id;
    # if ( exists $CHAIN{$key} ) {
    #     $a_chain = $CHAIN{$key};
    #     return;
    # }

    my $sel = <<'EOF';
        SELECT p.parent_id, p.nick, pm.value
        FROM pages AS p
        LEFT JOIN page_marks AS pm ON p.id = pm.page_id
        WHERE p.id = ?
        AND pm.lang_id = ?
        AND pm.name = 'page_name'
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $id, $lang_id );
    my ( $parent_id, $nick, $name ) = $sth->fetchrow_array();
    $sth->finish();

    unshift @{$a_chain}, {
        id        => $id,
        parent_id => $parent_id,
        name      => $name,
        nick      => $nick,
    };

    if ( $parent_id > 0 ) {
        get_chain(
            {
                dbh     => $dbh,
                lang_id => $lang_id,
                id      => $parent_id,
            },
            $a_chain
        );
    }

    # $CHAIN{$key} = $a_chain;

    return;
}

sub get_page {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $page_id = $args{page_id};

    my $sel = <<'EOF';
        SELECT parent_id, priority, hidden, navi_on, mode, name, nick
        FROM pages
        WHERE id = ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($page_id);
    my ( $parent_id, $priority, $hidden, $navi_on, $mode, $name, $nick ) = $sth->fetchrow_array();
    $sth->finish();

    return {
        id        => $page_id,
        parent_id => $parent_id,
        priority  => $priority,
        hidden    => $hidden,
        navi_on   => $navi_on,
        mode      => $mode,
        name      => $name,
        nick      => $nick,
    };
}

sub build_tree {
    my ($h_args) = @_;

    my $dbh        = $h_args->{dbh};
    my $root_dir   = $h_args->{root_dir};
    my $tpl_path   = $h_args->{tpl_path};
    my $tpl_name   = $h_args->{tpl_name};
    my $parent_id  = $h_args->{parent_id};
    my $level      = $h_args->{level};
    my $h_selected = $h_args->{h_selected};

    $parent_id  //= 0;
    $level      //= 0;
    $tpl_name   //= 'list-item';
    $h_selected //= {};

    my %sel    = %{$h_selected};
    my $result = q{};
    my $dash   = sprintf q{&nbsp;-} x $level;

    my $sel = <<'EOF';
        SELECT
            id,
            priority,
            hidden,
            navi_on,
            mode,
            name,
            nick
        FROM pages
        WHERE parent_id = ?
        ORDER BY priority DESC, name ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($parent_id);
    while ( my ( $id, $priority, $hidden, $navi_on, $mode, $name, $nick, $img_path )
        = $sth->fetchrow_array() ) {
        my $attr = q{};
        if ( exists $sel{$id} ) { $attr = q{ selected}; }

        my $mode_link = $MODE_LINK{$mode} ? sprintf( $MODE_LINK{$mode}, $id ) : q{};

        my $color_mode = $hidden ? $mode . 'h' : $mode;

        $result .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => $tpl_name . '.html',
            h_vars   => {
                id         => $id,
                parent_id  => $parent_id,
                priority   => $priority,
                hidden     => $hidden,
                navi_on    => $navi_on,
                mode       => $mode,
                name       => $name,
                nick       => $nick,
                attr       => $attr,
                dash       => $dash,
                mode_link  => $mode_link,
                color_mode => $color_mode,
            }
        );

        $result .= build_tree(
            {
                dbh        => $dbh,
                root_dir   => $root_dir,
                tpl_path   => $tpl_path,
                tpl_name   => $tpl_name,
                parent_id  => $id,
                level      => $level + 1,
                h_selected => $h_selected,
            }
        );
    }

    $sth->finish();
    return $result;
}

sub find_shop_root {
    my (%args) = @_;

    my $dbh = $args{dbh};

    my $wanted_mode = 1; # shop
    my $result_id   = 0;

    my $sel2 = 'SELECT mode FROM pages WHERE id = ?';
    my $sth2 = $dbh->prepare($sel2);

    my $sel = <<'EOF';
        SELECT
            id, parent_id
        FROM pages
        WHERE mode = ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($wanted_mode);
    while ( my ( $id, $parent_id ) = $sth->fetchrow_array() ) {
        $sth2->execute($parent_id);
        my ($parent_mode) = $sth2->fetchrow_array();

        if ( $parent_mode != $wanted_mode ) {
            $result_id = $id;
            last;
        }
    }

    $sth->finish();
    $sth2->finish();

    return $result_id;
}

sub update_child_qty {
    my (%args) = @_;

    my $dbh = $args{dbh};

    my $sel2 = 'SELECT COUNT(id) FROM pages WHERE hidden = 0 AND navi_on = 1 AND parent_id = ?';
    my $sth2 = $dbh->prepare($sel2);

    my $sel = 'SELECT id FROM pages';
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ($id) = $sth->fetchrow_array() ) {
        $sth2->execute($id);
        my ($child_qty) = $sth2->fetchrow_array();
        $dbh->do("UPDATE pages SET child_qty = $child_qty WHERE id = $id");
    }

    $sth->finish();
    $sth2->finish();

    return;
}

sub get_marks {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $page_id = $args{page_id};
    my $lang_id = $args{lang_id};

    my %result = ();

    my $sel = q{SELECT name, value FROM page_marks WHERE page_id = ? AND lang_id = ?};
    my $sth = $dbh->prepare($sel);
    $sth->execute( $page_id, $lang_id );
    while ( my ( $name, $value ) = $sth->fetchrow_array() ) {
        $result{$name} = $value;
    }

    $sth->finish();
    return \%result;
}

sub get_modes {
    my @modes = ();

    foreach my $id ( sort keys %MODE ) {
        push @modes, {
            id   => $id,
            name => $MODE{$id},
        };
    }

    return \@modes;
}

1;
