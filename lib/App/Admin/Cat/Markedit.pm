package App::Admin::Cat::Markedit;

use strict;
use warnings;

use Util::Renderer;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;
    my $page_id  = $o_params->{page_id} || 0;

    my $tpl_path = $app->config->{templates}->{path};
    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;

    my $h_prop = _get_properties( $dbh, $id );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/cat',
        tpl_name => 'mark-edit.html',
        h_vars   => {
            page_id => $page_id,
            %{$h_prop},
        },
    );

    my $page = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $body,
        },
    );

    return {
        body => $page,
    };
}

sub _get_properties {
    my ( $dbh, $id ) = @_;

    my $sel = q{SELECT lang_id, name, value FROM page_marks WHERE id = ?};
    my $sth = $dbh->prepare($sel);
    $sth->execute($id);
    my ( $lang_id, $name, $value ) = $sth->fetchrow_array();
    $sth->finish();

    return {
        id      => $id,
        lang_id => $lang_id,
        name    => $name,
        value   => Util::Renderer::do_escape($value),
    };
}

1;
