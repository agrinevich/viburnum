package App::Admin::Bkp;

use strict;
use warnings;

use Number::Bytes::Human qw(format_bytes);

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

    #
    # TODO: lisy zip files not dirs
    #
    my $a_bkps = Util::Files::get_files(
        dir       => $root_dir . $bkp_path,
        dirs_only => 1,
    );

    my @bkps = map { $_->{name} } @{$a_bkps};

    my $bkp_list = q{};
    foreach my $name ( sort @bkps ) {
        my $zip  = $root_dir . $bkp_path . q{/} . $name . '.zip';
        my $size = 0;
        if ( -e $zip ) {
            $size = -s $zip;
        }
        $bkp_list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/bkp',
            tpl_name => 'list-item.html',
            h_vars   => {
                name => $name,
                size => format_bytes($size),
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
