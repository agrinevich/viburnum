package App::Admin::Cat::Fileupload;

use strict;
use warnings;

use Util::Files;
use Util::Tree;
use Util::Langs;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $o_uploads = $o_request->uploads();

    my $page_id = $o_params->{page_id} || 0;
    my $lang_id = $o_params->{lang_id} || 0;
    my $file    = $o_uploads->{file};
    # my @files = $o_uploads->get_all('file');

    {
        my $h_lang = Util::Langs::get_lang(
            dbh     => $app->dbh,
            lang_id => $lang_id,
        );
        my $lang_path = $h_lang->{lang_path};

        my $page_path = Util::Tree::page_path(
            dbh     => $app->dbh,
            page_id => $page_id,
        );

        my $root_dir  = $app->root_dir;
        my $html_path = $app->config->{data}->{html_path};
        my $page_dir  = $root_dir . $html_path . $lang_path . $page_path;

        if ( !-d $page_dir ) {
            Util::Files::make_path(
                path => $page_dir,
            );
        }

        my $file_name = $file->basename;
        my @chunks    = split /[.]/, $file_name;
        my $ext       = pop @chunks;
        my $name      = join q{}, @chunks;

        $name =~ s/[^\w\-\_]//xmsg;
        if ( !$name ) {
            $name = time;
        }

        my $file_tmp = $file->path();
        my $new_file = $page_dir . q{/} . $name . q{.} . $ext;
        rename $file_tmp, $new_file;

        my $mode_readable = oct '644';
        chmod $mode_readable, $new_file;
    }

    return {
        url => $app->config->{site}->{host} . '/admin/cat/edit?id=' . $page_id,
    };
}

1;
