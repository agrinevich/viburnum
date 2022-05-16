package Util::Notes;

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);

use Util::Renderer;
use Util::Texter;
use Util::Tree;
use Util::Files;

our $VERSION = '1.1';

const my $NICK_MAX_LENGTH => 32;

sub list {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $lang_id   = $args{lang_id} || 1;
    my $page_id   = $args{page_id} || 0;
    my $offset    = $args{offset};
    my $npp       = $args{npp};
    my $order_by  = $args{order_by};
    my $order_how = $args{order_how};
    my $is_ext    = $args{is_ext};

    my @result = ();

    my $sel = <<'EOF';
        SELECT
            n.id, n.hidden, n.prio, n.add_dt, n.price,
            n.nick, nv.name, nv.descr, nv.p_title, nv.p_descr,
            nv.param_01, nv.param_02, nv.param_03, nv.param_04, nv.param_05
        FROM notes AS n
        LEFT JOIN notes_versions AS nv
            ON n.id = nv.note_id
        WHERE n.page_id = ?
        AND nv.lang_id = ?
        AND n.hidden = 0
EOF
    if ( defined $is_ext ) {
        $sel .= " AND n.is_ext = $is_ext";
    }
    if ( $order_by eq 'prio' ) {
        $sel .= ' ORDER BY n.prio';
    }
    elsif ( $order_by eq 'price' ) {
        $sel .= ' ORDER BY n.price';
    }
    elsif ( $order_by eq 'time' ) {
        $sel .= ' ORDER BY n.add_dt';
    }
    else {
        $sel .= ' ORDER BY nv.name';
    }
    if ( lc $order_how eq 'desc' ) {
        $sel .= ' DESC';
    }
    else {
        $sel .= ' ASC';
    }
    if ( defined $offset && defined $npp ) {
        $sel .= " LIMIT $offset, $npp";
    }
    my $sth = $dbh->prepare($sel);
    $sth->execute( $page_id, $lang_id );

    while (
        my (
            $id,       $hidden,   $prio,     $add_dt,   $price,
            $nick,     $name,     $descr,    $p_title,  $p_descr,
            $param_01, $param_02, $param_03, $param_04, $param_05
        )
        = $sth->fetchrow_array()
    ) {
        push @result, {
            id       => $id,
            hidden   => $hidden,
            prio     => $prio,
            add_dt   => $add_dt,
            price    => $price,
            nick     => $nick,
            name     => $name,
            descr    => $descr,
            p_title  => $p_title,
            p_descr  => $p_descr,
            param_01 => $param_01,
            param_02 => $param_02,
            param_03 => $param_03,
            param_04 => $param_04,
            param_05 => $param_05,
        };
    }

    $sth->finish();
    return \@result;
}

sub get_note {
    my (%args) = @_;

    my $dbh = $args{dbh};
    my $id  = $args{id};

    my $sel = <<'EOF';
        SELECT page_id, hidden, prio, add_dt, price, nick
        FROM notes
        WHERE id = ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($id);
    my ( $page_id, $hidden, $prio, $add_dt, $price, $nick ) = $sth->fetchrow_array();
    $sth->finish();

    return {
        id      => $id,
        page_id => $page_id,
        hidden  => $hidden,
        prio    => $prio,
        add_dt  => $add_dt,
        price   => $price,
        nick    => $nick,
    };
}

sub get_qty {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $page_id = $args{page_id};
    my $is_ext  = $args{is_ext};

    my $sel = <<'EOF';
        SELECT COUNT(id)
        FROM notes
        WHERE page_id = ?
        AND hidden = 0
EOF
    if ( defined $is_ext ) {
        $sel .= " AND is_ext = $is_ext";
    }
    my $sth = $dbh->prepare($sel);
    $sth->execute($page_id);
    my ($qty) = $sth->fetchrow_array();
    $sth->finish();

    return $qty // 0;
}

sub images {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $note_id = $args{note_id};

    my @images = ();

    my $sel = <<'EOF';
        SELECT id, num, path_sm, path_la
        FROM notes_images
        WHERE note_id = ?
        ORDER BY id ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($note_id);
    while ( my ( $id, $num, $path_sm, $path_la ) = $sth->fetchrow_array() ) {
        push @images, {
            note_id => $note_id,
            id      => $id,
            num     => $num,
            path_sm => $path_sm,
            path_la => $path_la,
        };
    }
    $sth->finish();

    return \@images;
}

#
# skip_decode = 0 if adding from webUI
# skip_decode = 1 if adding from csv file
#
sub build_nick {
    my (%args) = @_;

    my $note_id = $args{note_id};
    my $name    = $args{name};

    my $name_f = Util::Texter::translit(
        input       => $name,
        skip_decode => 0,
    );

    $name_f =~ s/[ _]+/-/g;
    $name_f =~ s/[^\w\d\-]//g;
    $name_f =~ s/_+/_/g;
    $name_f =~ s/^_+//xms;
    $name_f =~ s/_+$//xms;
    $name_f = lc $name_f;
    $name_f = substr $name_f, 0, $NICK_MAX_LENGTH;

    return $name_f . q{-} . $note_id;
}

sub build_p_descr {
    my (%args) = @_;

    my $page_name   = $args{page_name};
    my $note_name   = $args{note_name};
    my $lang_suffix = $args{lang_suffix};
    my $tpl_path    = $args{tpl_path};
    my $root_dir    = $args{root_dir};
    my $skin        = $args{skin};

    my $skin_tpl_path = $tpl_path . q{/} . $skin;
    my $tpl_name      = "meta-descr${lang_suffix}.txt";

    my $tpl_file         = $root_dir . $skin_tpl_path . q{/} . $tpl_name;
    my $tpl_file_primary = $root_dir . $skin_tpl_path . '/meta-descr.txt';
    if ( !-e $tpl_file ) {
        Util::Files::copy_file(
            src => $tpl_file_primary,
            dst => $tpl_file,
        );
    }

    return Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_name => $tpl_name,
        h_vars   => {
            page_name => $page_name,
            name      => $note_name,
        },
    );
}

1;
