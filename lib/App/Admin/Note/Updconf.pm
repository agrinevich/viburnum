package App::Admin::Note::Updconf;

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);

use Util::Config;
use Util::Tree;
use Util::Files;

our $VERSION = '1.1';

const my $MODE_NAME => 'note';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $page_id  = $o_params->{page_id} || 0;

    my $root_dir   = $app->root_dir;
    my $html_path  = $app->config->{data}->{html_path};
    my $tpl_path_f = $app->config->{templates}->{path_f};

    my $base_path = Util::Tree::page_path(
        dbh     => $app->dbh,
        page_id => $page_id,
    );
    my $config_name = $MODE_NAME . q{-} . $page_id . '.conf';
    my $config_dir  = $root_dir . $html_path . $base_path;

    my $o_conf = Util::Config::get_config(
        file => $config_dir . q{/} . $config_name,
    );

    my $old_skin = $o_conf->{$MODE_NAME}->{skin};

    foreach my $param_name ( keys %{ $o_conf->{$MODE_NAME} } ) {
        $o_conf->{$MODE_NAME}->{$param_name} = $o_params->{$param_name};
    }

    # check (and fix) new skin name
    $o_conf->{$MODE_NAME}->{skin} =~ s/[^\w\-]//g;
    if ( !$o_conf->{$MODE_NAME}->{skin} ) {
        $o_conf->{$MODE_NAME}->{skin} = $old_skin;
    }

    # check if new skin dir exists (duplicated)
    if ( $old_skin ne $o_conf->{$MODE_NAME}->{skin} ) {
        my $new_skin_dir = $root_dir . $tpl_path_f . q{/} . $o_conf->{$MODE_NAME}->{skin};
        if ( -d $new_skin_dir ) {
            $o_conf->{$MODE_NAME}->{skin} = $old_skin;
        }
        else {
            move_skin(
                old_skin_dir => $root_dir . $tpl_path_f . q{/} . $old_skin,
                new_skin_dir => $new_skin_dir,
            );
        }
    }

    Util::Config::save_config(
        {
            file => $config_dir . q{/} . $config_name,
        },
        $o_conf,
    );

    my $host = $app->config->{site}->{host};
    my $url  = $host . q{/admin/note?page_id=} . $page_id;

    return {
        url => $url,
    };
}

sub move_skin {
    my (%args) = @_;

    my $src_dir = $args{old_skin_dir};
    my $dst_dir = $args{new_skin_dir};

    return if !-d $src_dir;

    # if ( !-d $dst_dir ) {
    #     Util::Files::make_path(
    #         path => $dst_dir,
    #     );
    # }

    # my $a_files = Util::Files::get_files(
    #     dir => $src_dir,
    # );

    # foreach my $h ( @{$a_files} ) {
    #     my $src_file = $src_dir . q{/} . $h->{name};
    #     my $dst_file = $dst_dir . q{/} . $h->{name};
    #     Util::Files::move_file(
    #         src => $src_file,
    #         dst => $dst_file,
    #     );
    # }

    # rmdir $src_dir;

    Util::Files::copy_dir_recursive(
        src_dir => $src_dir,
        dst_dir => $dst_dir,
    );

    Util::Files::empty_dir_recursive(
        dir => $src_dir,
    );

    rmdir $src_dir;

    return;
}

1;
