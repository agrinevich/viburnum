package App::Admin::Note::Delete;

use strict;
use warnings;

use Util::Notes;
use Util::Langs;
use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;

    my $dbh       = $app->dbh;
    my $root_dir  = $app->root_dir;
    my $html_path = $app->config->{data}->{html_path};
    my $img_path  = $app->config->{data}->{images_path2};

    my $h_note = Util::Notes::get_note(
        id  => $id,
        dbh => $dbh,
    );

    my $base_path = Util::Tree::page_path(
        dbh     => $dbh,
        page_id => $h_note->{page_id},
    );

    # remove images
    my $a_images = Util::Notes::images(
        note_id => $id,
        dbh     => $dbh,
    );
    foreach my $h_img ( @{$a_images} ) {
        my $img_sm = $root_dir . $html_path . $h_img->{path_sm};
        my $img_la = $root_dir . $html_path . $h_img->{path_la};

        if ( -e $img_sm ) {
            unlink $img_sm;
        }
        if ( -e $img_la ) {
            unlink $img_la;
        }
    }

    # remove page for each lang version
    my $a_langs = Util::Langs::get_langs( dbh => $dbh );
    foreach my $h_lang ( @{$a_langs} ) {
        my $details_path = $h_lang->{lang_path} . $base_path;
        my $details_file = $h_note->{nick} . '.html';
        my $page_path    = $details_path . q{/} . $details_file;

        unlink $root_dir . $html_path . $page_path;
    }

    $dbh->do("DELETE FROM notes_images WHERE note_id = $id");
    $dbh->do("DELETE FROM notes_versions WHERE note_id = $id");
    $dbh->do("DELETE FROM notes WHERE id = $id");

    my $host = $app->config->{site}->{host};
    my $url  = $host . '/admin/note?page_id=' . $h_note->{page_id};

    return {
        url => $url,
    };
}

1;
