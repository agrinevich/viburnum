package App::Admin::Cat;

use strict;
use warnings;

use Util::Renderer;
use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $msg      = $o_params->{msg} // q{};

    my $tpl_path = $app->config->{templates}->{path};
    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;

    my $tree = Util::Tree::build_tree(
        {
            dbh        => $dbh,
            root_dir   => $root_dir,
            tpl_path   => $tpl_path,
            tpl_name   => 'list-item',
            parent_id  => 0,
            level      => 0,
            h_selected => {},
        }
    );

    my $cat_options = Util::Tree::build_tree(
        {
            dbh        => $dbh,
            root_dir   => $root_dir,
            tpl_path   => $tpl_path,
            tpl_name   => 'option',
            parent_id  => 0,
            level      => 0,
            h_selected => {},
        }
    );

    my $msg_text = q{};
    if ($msg) {
        $msg_text = Util::Renderer::build_msg(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => 'msg-text.html',
            msg      => $msg,
        );
    }

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/cat',
        tpl_name => 'list.html',
        h_vars   => {
            list        => $tree,
            cat_options => $cat_options,
            msg_text    => $msg_text,
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
