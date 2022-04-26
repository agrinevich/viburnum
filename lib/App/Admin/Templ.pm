package App::Admin::Templ;

use strict;
use warnings;

use Util::Renderer;
use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $fdir     = $o_params->{fdir} // q{};
    my $fname    = $o_params->{fname} // q{};

    my $tpl_path = $app->config->{templates}->{path};
    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;

    my $cur_file = q{};
    my $fcode    = q{};
    if ($fname) {
        $cur_file = $fdir . q{/} . $fname;
        $fcode    = Util::Files::read_file( file => $cur_file );
        $fcode    = Util::Renderer::do_escape($fcode);
    }

    my $tree = Util::Files::build_tree(
        {
            root_dir    => $root_dir,
            tpl_path    => $tpl_path,
            parent_path => $app->config->{templates}->{path_f},
            level       => 0,
            h_selected  => { $cur_file => ' class=bold' },
        }
    );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/templ',
        tpl_name => 'list.html',
        h_vars   => {
            list  => $tree,
            fdir  => $fdir,
            fname => $fname,
            fcode => $fcode,
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
