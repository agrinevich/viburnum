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
    my $bkp_dir  = $root_dir . $bkp_path . q{/} . $bkp_name;

    # 1. templates backup

    my $tplbkp_dir = $bkp_dir . '/tpl';
    Util::Files::make_path( path => $tplbkp_dir );

    my $src_path = $app->config->{templates}->{path_f};
    my $src_dir  = $root_dir . $src_path;
    Util::Files::copy_dir_recursive(
        src_dir => $src_dir,
        dst_dir => $tplbkp_dir,
    );

    # 2. database backup

    my $sqlbkp_dir = $bkp_dir . '/sql';
    Util::Files::make_path( path => $sqlbkp_dir );

    # give 'mysql' user permission to write
    my $mode1 = oct '777';
    chmod $mode1, $sqlbkp_dir;

    _select_to_file(
        dbh    => $dbh,
        file   => $sqlbkp_dir . '/global_marks.txt',
        table  => 'global_marks',
        fields => 'id, name, value',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $sqlbkp_dir . '/langs.txt',
        table  => 'langs',
        fields => 'id, name, nick, isocode',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $sqlbkp_dir . '/page_marks.txt',
        table  => 'page_marks',
        fields => 'id, page_id, lang_id, name, value',
    );

    _select_to_file(
        dbh   => $dbh,
        file  => $sqlbkp_dir . '/pages.txt',
        table => 'pages',
        fields =>
            'id, parent_id, priority, hidden, navi_on, changed, mode, child_qty, good_qty, name, nick',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $sqlbkp_dir . '/plugins.txt',
        table  => 'plugins',
        fields => 'id, app, nick',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $sqlbkp_dir . '/notes.txt',
        table  => 'notes',
        fields => 'id, page_id, hidden, prio, add_dt, price, nick, is_ext, ip',
    );

    _select_to_file(
        dbh   => $dbh,
        file  => $sqlbkp_dir . '/notes_versions.txt',
        table => 'notes_versions',
        fields =>
            'id, note_id, lang_id, name, param_01, param_02, param_03, param_04, param_05, p_title, p_descr, descr',
    );

    _select_to_file(
        dbh    => $dbh,
        file   => $sqlbkp_dir . '/notes_images.txt',
        table  => 'notes_images',
        fields => 'id, note_id, num, path_sm, path_la',
    );

    # reset permission to write
    my $mode2 = oct '755';
    chmod $mode2, $sqlbkp_dir;

    my $h_zip = Util::Files::create_zip(
        src_dir => $bkp_dir,
        dst_dir => $root_dir . $bkp_path,
        name    => $bkp_name,
    );

    Util::Files::empty_dir_recursive( dir => $bkp_dir );
    rmdir $bkp_dir;

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
