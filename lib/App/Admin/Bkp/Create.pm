package App::Admin::Bkp::Create;

use strict;
use warnings;

use POSIX ();
use POSIX qw(strftime);
use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    # my $o_params = $o_request->parameters();

    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;
    my $bkp_path = $app->config->{bkp}->{path};
    my $bkp_name = strftime( '%Y%m%d-%H%M%S', localtime );

    # 1. templates backup

    my $bkp_dir = $root_dir . $bkp_path . q{/} . $bkp_name . '/tpl';
    Util::Files::make_path( path => $bkp_dir );

    my $src_path = $app->config->{templates}->{path_f};
    my $src_dir  = $root_dir . $src_path;
    Util::Files::copy_dir_recursive(
        src_dir => $src_dir,
        dst_dir => $bkp_dir,
    );

    # 2. database backup

    my $bkp_dir2 = $root_dir . $bkp_path . q{/} . $bkp_name . '/sql';
    Util::Files::make_path( path => $bkp_dir2 );

    # give 'mysql' user permission to write
    my $mode1 = oct '777';
    chmod $mode1, $bkp_dir2;

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/global_marks.txt',
        table  => 'global_marks',
        fields => 'id, name, value',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/langs.txt',
        table  => 'langs',
        fields => 'id, name, nick, isocode',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/page_marks.txt',
        table  => 'page_marks',
        fields => 'id, page_id, lang_id, name, value',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/pages.txt',
        table  => 'pages',
        fields => 'id, parent_id, priority, hidden, navi_on, changed, name, nick',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/notes.txt',
        table  => 'notes',
        fields => 'id, page_id, hidden, prio, add_dt, price, nick',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/notes_versions.txt',
        table  => 'notes_versions',
        fields => 'id, note_id, lang_id, name, p_title, p_descr, descr',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $bkp_dir2 . '/notes_images.txt',
        table  => 'notes_images',
        fields => 'id, note_id, num, path_sm, path_la',
    );

    # reset permission to write
    my $mode2 = oct '755';
    chmod $mode2, $bkp_dir2;

    return {
        url => $app->config->{site}->{host} . '/admin/bkp?msg=success',
    };
}

sub _select_to_file {
    my (%args) = @_;

    my $dbh    = $args{dbh};
    my $file   = $args{file};
    my $table  = $args{table};
    my $fields = $args{fields};

    my $sel_tpl = <<'EOF';
        SELECT %s
        INTO OUTFILE ?
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\n'
        FROM %s
EOF
    my $sel = sprintf $sel_tpl, $fields, $table;
    my $sth = $dbh->prepare($sel);
    $sth->execute($file);
    $sth->finish;

    return 1;
}

1;
