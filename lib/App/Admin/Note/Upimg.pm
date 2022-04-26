package App::Admin::Note::Upimg;

use strict;
use warnings;

use Carp qw(croak carp);

use Util::Images;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $id        = $o_params->{id} || 0;
    my $page_id   = $o_params->{page_id} || 0;
    my $o_uploads = $o_request->uploads();
    my $o_file    = $o_uploads->{file};
    my $file_src  = $o_file->path();
    my $base_name = $o_file->basename();
    # my @files  = $o_uploads->get_all('file');

    my @chunks = split /[.]/, $base_name;
    my $ext    = pop @chunks;

    $app->dbh->do("INSERT INTO notes_images (note_id) VALUES ($id)");

    my $sel = 'SELECT LAST_INSERT_ID()';
    my $sth = $app->dbh->prepare($sel);
    $sth->execute();
    my ($img_id) = $sth->fetchrow_array();
    $sth->finish();

    my $root_dir  = $app->root_dir;
    my $html_path = $app->config->{data}->{html_path};
    my $img_path  = $app->config->{data}->{images_path2};
    my $img_name  = $id . q{-} . $img_id . q{.} . $ext;
    my $img_dir   = $root_dir . $html_path . $img_path;
    my $file_orig = $img_dir . "/$img_name";

    my $img_path_sm = $img_path . '/sm/' . $img_name;
    my $img_path_la = $img_path . '/la/' . $img_name;
    my $img_file_la = $img_dir . '/la/' . $img_name;
    my $img_file_sm = $img_dir . '/sm/' . $img_name;

    my $upd_tpl = <<'EOF';
        UPDATE notes_images
        SET path_sm = "%s", path_la = "%s"
        WHERE id = %u
EOF
    my $upd = sprintf $upd_tpl, $img_path_sm, $img_path_la, $img_id;
    my $rv  = $app->dbh->do($upd);
    if ( !$rv ) {
        carp( 'Failed notes image update: ' . $app->dbh->errstr );
    }

    rename $file_src, $file_orig;

    my $success = Util::Images::scale_image(
        file_src => $file_orig,
        file_dst => $img_file_la,
        width    => $app->config->{data}->{img_maxw_la},
        height   => $app->config->{data}->{img_maxh_la},
    );
    if ( !$success ) {
        carp( 'Failed to scale to large image: ' . $file_orig );
    }

    my $success2 = Util::Images::scale_image(
        file_src => $file_orig,
        file_dst => $img_file_sm,
        width    => $app->config->{data}->{img_maxw_sm},
        height   => $app->config->{data}->{img_maxh_sm},
    );
    if ( !$success2 ) {
        carp( 'Failed to scale to small image: ' . $file_orig );
    }

    unlink $file_orig;

    my $host = $app->config->{site}->{host};
    my $url  = $host . q{/admin/note/edit?id=} . $id;

    return {
        url => $url,
    };
}

1;
