package App::Admin::Bkp;

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
    my $msg      = $o_params->{msg} // q{};

    my $tpl_path = $app->config->{templates}->{path};
    my $bkp_path = $app->config->{bkp}->{path};
    my $root_dir = $app->root_dir;
    my $bkp_dir  = $root_dir . $bkp_path;

    my $a_bkps = Util::Files::get_files(
        dir        => $bkp_dir,
        files_only => 1,
    );

    my @bkp_size = map { $_->{name} => $_->{size} } @{$a_bkps};
    my %bkp_size = @bkp_size;
    my $bkp_list = q{};
    my $tpl_item;
    foreach my $name ( sort keys %bkp_size ) {
        my $zip  = $bkp_dir . q{/} . $name;
        my $size = $bkp_size{$name};

        if   ( index( $name, '_' ) == -1 ) { $tpl_item = 'list-item.html'; }
        else                               { $tpl_item = 'list-itemf.html'; }

        $bkp_list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/bkp',
            tpl_name => $tpl_item,
            h_vars   => {
                name => $name,
                size => $size,
            },
        );
    }

    my $msg_text = Util::Renderer::build_msg(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => 'msg-text.html',
        msg      => $msg,
    );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/bkp',
        tpl_name => 'list.html',
        h_vars   => {
            list     => $bkp_list,
            msg_text => $msg_text,
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
