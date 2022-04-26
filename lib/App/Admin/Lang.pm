package App::Admin::Lang;

use strict;
use warnings;

use Util::Renderer;
use Util::Langs;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $tpl_path = $app->config->{templates}->{path};
    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;

    my $a_langs = Util::Langs::get_langs( dbh => $dbh );
    my $list    = q{};
    foreach my $h ( @{$a_langs} ) {
        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/lang',
            tpl_name => 'list-item.html',
            h_vars   => {
                id      => $h->{lang_id},
                name    => $h->{lang_name},
                nick    => $h->{lang_nick},
                isocode => $h->{lang_isocode},
            },
        );
    }

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/lang',
        tpl_name => 'list.html',
        h_vars   => {
            list => $list,
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
