package App::Admin::Bkp::Restore;

use strict;
use warnings;

use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $file_name = $o_params->{name} || q{-}; # better to have non-empty
    my $want_tpl  = $o_params->{tpl} || 0;
    my $want_sql  = $o_params->{sql} || 0;

    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;
    my $bkp_path = $app->config->{bkp}->{path};

    my $zip_file = $root_dir . $bkp_path . q{/} . $file_name;
    my $err      = Util::Files::extract_zip(
        file    => $zip_file,
        dst_dir => $root_dir . $bkp_path,
    );
    if ($err) {
        $app->logger->error($err);
        return {
            url => $app->config->{site}->{host} . '/admin/bkp?msg=error',
        };
    }

    # backup is extracted here
    my ( $bkp_name, undef ) = split /\./, $file_name;
    my $tmp_dir = $root_dir . $bkp_path . q{/} . $bkp_name;

    # templates backup
    if ($want_tpl) {
        my $dst_path = $app->config->{templates}->{path_f};
        my $dst_dir  = $root_dir . $dst_path;
        my $src_dir  = $tmp_dir . '/tpl';

        Util::Files::copy_dir_recursive(
            src_dir => $src_dir,
            dst_dir => $dst_dir,
        );
    }

    # sql data backup
    if ($want_sql) {
        my $src_dir = $tmp_dir . '/sql';

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/global_marks.txt',
            table => 'global_marks',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/langs.txt',
            table => 'langs',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/page_marks.txt',
            table => 'page_marks',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/pages.txt',
            table => 'pages',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/plugins.txt',
            table => 'plugins',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/notes.txt',
            table => 'notes',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/notes_versions.txt',
            table => 'notes_versions',
        );

        _load_from_file(
            dbh   => $dbh,
            file  => $src_dir . '/notes_images.txt',
            table => 'notes_images',
        );
    }

    Util::Files::empty_dir_recursive( dir => $tmp_dir );
    rmdir $tmp_dir;

    return {
        url => $app->config->{site}->{host} . '/admin/bkp?msg=success',
    };
}

sub _load_from_file {
    my (%args) = @_;

    my $dbh   = $args{dbh};
    my $file  = $args{file};
    my $table = $args{table};

    return "File not found: $file" if !( -f $file );

    my $del = qq{DELETE FROM $table WHERE id > 0};
    $dbh->do($del);

    # my $alt_1 = qq{ALTER TABLE $table DISABLE KEYS};
    # $dbh->do($alt_1);

    my $sel_tpl = <<'EOF';
        LOAD DATA INFILE ?
        INTO TABLE %s
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\n'
EOF
    my $sel = sprintf $sel_tpl, $table;
    my $sth = $dbh->prepare($sel);
    $sth->execute($file);
    $sth->finish;

    # my $alt_2 = qq{ALTER TABLE $table ENABLE KEYS};
    # $dbh->do($alt_2);

    return;
}

1;
