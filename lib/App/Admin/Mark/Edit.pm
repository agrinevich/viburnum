package App::Admin::Mark::Edit;

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

    my $tpl_path = $app->config->{templates}->{path};
    my $root_dir = $app->root_dir;

    my $sel = q{SELECT name, value FROM global_marks WHERE id = ?};
    my $sth = $app->dbh->prepare($sel);
    $sth->execute($id);
    my ( $name, $value ) = $sth->fetchrow_array();
    $sth->finish();

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/mark',
        tpl_name => 'edit.html',
        h_vars   => {
            id    => $id,
            name  => $name,
            value => Util::Renderer::do_escape($value),
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

1;
