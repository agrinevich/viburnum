package App::Admin::Note::Delimg;

use strict;
use warnings;

use Carp qw(croak carp);

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;
    my $note_id  = $o_params->{note_id} || 0;

    my $sel = 'SELECT path_sm, path_la FROM notes_images WHERE id = ?';
    my $sth = $app->dbh->prepare($sel);
    $sth->execute($id);
    my ( $img_path_sm, $img_path_la ) = $sth->fetchrow_array();
    $sth->finish();

    $app->dbh->do("DELETE FROM notes_images WHERE id = $id");

    my $root_dir  = $app->root_dir;
    my $html_path = $app->config->{data}->{html_path};

    my $img_file_la = $root_dir . $html_path . $img_path_sm;
    my $img_file_sm = $root_dir . $html_path . $img_path_la;

    if ( -f $img_file_la ) {
        unlink $img_file_la;
    }

    if ( -f $img_file_sm ) {
        unlink $img_file_sm;
    }

    my $host = $app->config->{site}->{host};
    my $url  = $host . q{/admin/note/edit?id=} . $note_id;

    return {
        url => $url,
    };
}

1;
