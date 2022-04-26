package App::Admin::Lang::Delete;

use strict;
use warnings;

use English qw( -no_match_vars );
use Carp qw(croak carp);

use Util::Langs;
use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id};

    if ( $id == 1 ) {
        return {
            url => $app->config->{site}->{host} . '/admin/lang',
        };
    }

    my $h_lang = Util::Langs::get_lang(
        dbh     => $app->dbh,
        lang_id => $id,
    );

    my $root_dir  = $app->root_dir;
    my $html_path = $app->config->{data}->{html_path};
    my $lang_dir  = $root_dir . $html_path . $h_lang->{lang_path};

    if ( -d $lang_dir ) {
        Util::Files::empty_dir_recursive(
            dir => $lang_dir,
        );
        rmdir $lang_dir or croak($OS_ERROR);
    }

    my $del = "DELETE FROM page_marks WHERE lang_id = $id";
    $app->dbh->do($del);

    my $del2 = "DELETE FROM notes_versions WHERE lang_id = $id";
    $app->dbh->do($del2);

    my $del3 = "DELETE FROM goods_versions WHERE lang_id = $id";
    $app->dbh->do($del3);

    my $del0 = "DELETE FROM langs WHERE id = $id";
    $app->dbh->do($del0);

    return {
        url => $app->config->{site}->{host} . '/admin/lang',
    };
}

1;
