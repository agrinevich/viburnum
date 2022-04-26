package App::Admin::Good::Import;

use strict;
use warnings;

use Util::Tree;
use Util::Files;
use Util::Renderer;
use Util::Supplier;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;
    my $tpl_path = $app->config->{templates}->{path};

    my $shop_root_id = Util::Tree::find_shop_root( dbh => $dbh );
    my $cat_options  = Util::Tree::build_tree(
        {
            dbh        => $dbh,
            root_dir   => $root_dir,
            tpl_path   => $tpl_path,
            tpl_name   => 'option',
            parent_id  => $shop_root_id,
            level      => 0,
            h_selected => {},
        }
    );

    my $a_suppliers = Util::Supplier::list( dbh => $dbh );
    my $sup_options = Util::Renderer::build_options(
        items    => $a_suppliers,
        id_sel   => 0,
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_file => 'sup-option.html',
    );

    my $sup_xml_list = _sup_xml_list( app => $app );

    my ( $files_ready, $a_files_ready ) = _file_list(
        app         => $app,
        sub_path    => '/ready',
        tpl_name    => 'import-ready.html',
        sup_options => $sup_options,
    );

    my $file_options = Util::Renderer::build_options(
        items    => $a_files_ready,
        id_sel   => 0,
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_file => 'import-ready-option.html',
    );

    my ( $files_raw, $a_files_raw ) = _file_list(
        app         => $app,
        sub_path    => '/raw',
        tpl_name    => 'import-raw.html',
        sup_options => $sup_options,
    );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_name => 'import.html',
        h_vars   => {
            list_xml     => $sup_xml_list,
            files_raw    => $files_raw,
            files_ready  => $files_ready,
            file_options => $file_options,
            cat_options  => $cat_options,
            sup_options  => $sup_options,
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

sub _file_list {
    my (%args) = @_;

    my $app         = $args{app};
    my $sub_path    = $args{sub_path};
    my $tpl_name    = $args{tpl_name};
    my $sup_options = $args{sup_options};

    my $site_host   = $app->config->{site}->{host};
    my $prices_path = $app->config->{data}->{prices_path};
    my $dir         = $app->root_dir . $prices_path . $sub_path;

    my $a_files = Util::Files::get_files( dir => $dir );

    my $list  = q{};
    my @files = ();
    foreach my $h_file ( @{$a_files} ) {
        $list .= Util::Renderer::parse_html(
            root_dir => $app->root_dir,
            tpl_path => $app->config->{templates}->{path} . '/good',
            tpl_name => $tpl_name,
            h_vars   => {
                http_domain => $site_host,
                path        => $prices_path . $sub_path,
                name        => $h_file->{name},
                size        => $h_file->{size},
                sup_options => $sup_options,
            },
        );

        push @files, {
            # id   => $prices_path . $sub_path . q{/} . $h_file->{name},
            id   => $h_file->{name},
            name => $h_file->{name},
        };
    }

    return ( $list, \@files );
}

sub _sup_xml_list {
    my (%args) = @_;

    my $app = $args{app};

    my $a_sups = Util::Supplier::list( dbh => $app->dbh );
    my $list   = q{};

    foreach my $h ( @{$a_sups} ) {
        my $section = 'supplier_' . $h->{id};
        my $xml_url = $app->config->{$section}->{xml_url};

        $list .= Util::Renderer::parse_html(
            root_dir => $app->root_dir,
            tpl_path => $app->config->{templates}->{path} . '/good',
            tpl_name => 'sup-xml.html',
            h_vars   => {
                sup_id   => $h->{id},
                sup_name => $h->{name},
                xml_url  => $xml_url,
            },
        );
    }

    return $list;
}

1;
