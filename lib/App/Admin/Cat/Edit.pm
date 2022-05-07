package App::Admin::Cat::Edit;

use strict;
use warnings;

use Util::Renderer;
use Util::Langs;
use Util::Files;
use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;

    my $tpl_path  = $app->config->{templates}->{path};
    my $html_path = $app->config->{data}->{html_path};
    my $dbh       = $app->dbh;
    my $root_dir  = $app->root_dir;

    my $h_page = Util::Tree::get_page(
        dbh     => $dbh,
        page_id => $id,
    );

    my $parent_id   = $h_page->{parent_id};
    my $cat_options = q{};
    if ( !$parent_id ) {
        $cat_options = q{<option value="0">root</option>};
    }
    else {
        $cat_options = Util::Tree::build_tree(
            {
                dbh        => $dbh,
                root_dir   => $root_dir,
                tpl_path   => $tpl_path,
                tpl_name   => 'option',
                parent_id  => 0,
                level      => 0,
                h_selected => { $parent_id => ' selected' },
            }
        );
    }

    my $lang_versions = _get_lang_versions(
        dbh       => $dbh,
        root_dir  => $root_dir,
        tpl_path  => $tpl_path,
        html_path => $html_path,
        page_id   => $id,
    );

    my $a_modes      = Util::Tree::get_modes( dbh => $dbh );
    my $mode_options = Util::Renderer::build_options(
        items    => $a_modes,
        id_sel   => $h_page->{mode},
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_file => 'mode-option.html',
    );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/cat',
        tpl_name => 'edit.html',
        h_vars   => {
            mode_options  => $mode_options,
            cat_options   => $cat_options,
            lang_versions => $lang_versions,
            %{$h_page},
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

# sub _get_properties {
#     my ( $dbh, $id ) = @_;

#     my $sel
#         = q{SELECT parent_id, priority, hidden, navi_on, mode, name, nick FROM pages WHERE id = ?};
#     my $sth = $dbh->prepare($sel);
#     $sth->execute($id);
#     my (
#         $parent_id,
#         $priority,
#         $hidden,
#         $navi_on,
#         $mode,
#         $name,
#         $nick
#     ) = $sth->fetchrow_array();
#     $sth->finish();

#     return if !defined $name;

#     return {
#         id        => $id,
#         parent_id => $parent_id,
#         priority  => $priority,
#         hidden    => $hidden,
#         navi_on   => $navi_on,
#         mode      => $mode,
#         name      => Util::Renderer::do_escape($name),
#         nick      => $nick,
#     };
# }

sub _get_lang_versions {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $root_dir  = $args{root_dir};
    my $tpl_path  = $args{tpl_path};
    my $html_path = $args{html_path};
    my $page_id   = $args{page_id};

    my $result = q{};

    my $a_langs = Util::Langs::get_langs(
        dbh => $dbh,
    );

    foreach my $h ( @{$a_langs} ) {
        $result .= _get_lang_version(
            dbh       => $dbh,
            root_dir  => $root_dir,
            tpl_path  => $tpl_path,
            html_path => $html_path,
            page_id   => $page_id,
            h_lang    => $h,
        );
    }

    return $result;
}

sub _get_lang_version {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $root_dir  = $args{root_dir};
    my $tpl_path  = $args{tpl_path};
    my $html_path = $args{html_path};
    my $page_id   = $args{page_id};
    my $h_lang    = $args{h_lang};

    my $result = q{};

    my $marks = _get_lang_marks(
        dbh      => $dbh,
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        page_id  => $page_id,
        h_lang   => $h_lang,
    );

    my $files = _get_lang_files(
        dbh       => $dbh,
        root_dir  => $root_dir,
        tpl_path  => $tpl_path,
        html_path => $html_path,
        page_id   => $page_id,
        h_lang    => $h_lang,
    );

    $result = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/cat',
        tpl_name => 'lang-box.html',
        h_vars   => {
            page_id   => $page_id,
            lang_name => $h_lang->{lang_name},
            lang_id   => $h_lang->{lang_id},
            marks     => $marks,
            files     => $files,
        },
    );

    return $result;
}

sub _get_lang_marks {
    my (%args) = @_;

    my $dbh      = $args{dbh};
    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $page_id  = $args{page_id};
    my $h_lang   = $args{h_lang};

    my $result = q{};

    my $sel = <<'EOF';
		SELECT id, name, value
		FROM page_marks
		WHERE page_id = ?
        AND lang_id = ?
		ORDER BY name ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $page_id, $h_lang->{lang_id} );
    while ( my ( $id, $name, $value ) = $sth->fetchrow_array() ) {
        $result .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => 'mark-link.html',
            h_vars   => {
                id      => $id,
                name    => $name,
                page_id => $page_id,
                # value   => $value,
                # lang_id => $h_lang->{lang_id},
            },
        );
    }
    $sth->finish();

    return $result;
}

sub _get_lang_files {
    my (%args) = @_;

    my $dbh       = $args{dbh};
    my $root_dir  = $args{root_dir};
    my $tpl_path  = $args{tpl_path};
    my $html_path = $args{html_path};
    my $page_id   = $args{page_id};
    my $h_lang    = $args{h_lang};

    my $result = q{};

    my $page_path = Util::Tree::page_path(
        dbh     => $dbh,
        page_id => $page_id,
    );

    $page_path = $h_lang->{lang_path} . $page_path;

    my $a_files = Util::Files::get_files(
        dir        => $root_dir . $html_path . $page_path,
        files_only => 1,
    );

    foreach my $h_file ( @{$a_files} ) {
        $result .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => 'file-link.html',
            h_vars   => {
                name    => $h_file->{name},
                size    => $h_file->{size},
                path    => $page_path,
                page_id => $page_id,
            },
        );
    }

    return $result;
}

1;
