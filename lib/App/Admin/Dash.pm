package App::Admin::Dash;

use strict;
use warnings;

use Util::Renderer;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $h_ch = _changed_qty( $app->dbh );

    my $tpl_path = $app->config->{templates}->{path};

    my $body = Util::Renderer::parse_html(
        root_dir => $app->root_dir,
        tpl_path => $tpl_path . '/dash',
        tpl_name => 'board.html',
        h_vars   => {
            cat_qty    => $h_ch->{cat_qty},
            cat_ch_qty => $h_ch->{cat_ch_qty},
        },
    );

    my $page = Util::Renderer::parse_html(
        root_dir => $app->root_dir,
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

sub _changed_qty {
    my ($dbh) = @_;

    my $sel = q{SELECT COUNT(*) FROM pages WHERE changed = 1};
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    my ($cat_ch_qty) = $sth->fetchrow_array();
    $sth->finish();

    $sel = q{SELECT COUNT(*) FROM pages};
    $sth = $dbh->prepare($sel);
    $sth->execute();
    my ($cat_qty) = $sth->fetchrow_array();
    $sth->finish();

    return {
        cat_qty    => $cat_qty,
        cat_ch_qty => $cat_ch_qty,
    };
}

1;
