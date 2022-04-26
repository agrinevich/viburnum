package App::Admin::Note::Edit;

use strict;
use warnings;

use Util::Renderer;
use Util::Notes;
use Util::Config;
use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;

    my $tpl_path   = $app->config->{templates}->{path};
    my $tpl_path_f = $app->config->{templates}->{path_f};
    my $html_path  = $app->config->{data}->{html_path};
    my $root_dir   = $app->root_dir;
    my $dbh        = $app->dbh;

    my $h_note = Util::Notes::get_note(
        id  => $id,
        dbh => $dbh,
    );

    my $base_path = Util::Tree::page_path(
        dbh     => $dbh,
        page_id => $h_note->{page_id},
    );

    my $o_mode_config = Util::Config::get_mode_config(
        root_dir  => $root_dir,
        page_id   => $h_note->{page_id},
        html_path => $html_path,
        base_path => $base_path,
        mode_name => 'note',
    );

    my $skin_tpl_path = $tpl_path_f . q{/} . $o_mode_config->{note}->{skin};

    my $versions = q{};
    {
        my $a_versions = _get_versions(
            dbh     => $dbh,
            note_id => $id,
        );
        foreach my $h ( @{$a_versions} ) {
            $versions .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $skin_tpl_path,
                tpl_name => 'a-edit-version.html',
                h_vars   => $h,
            );
        }
    }

    my $images = q{};
    {
        my $a_images = Util::Notes::images(
            note_id => $id,
            dbh     => $dbh,
        );
        foreach my $h ( @{$a_images} ) {
            $images .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $skin_tpl_path,
                tpl_name => 'a-edit-image.html',
                h_vars   => $h,
            );
        }
    }

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $skin_tpl_path,
        tpl_name => 'a-edit.html',
        h_vars   => {
            versions => $versions,
            images   => $images,
            %{$h_note},
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

sub _get_versions {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $note_id = $args{note_id};

    my @versions = ();

    my $sel = <<'EOF';
        SELECT
            nv.id, nv.lang_id, nv.name, nv.p_title, nv.p_descr, nv.descr,
            nv.param_01, nv.param_02, nv.param_03, nv.param_04, nv.param_05,
            l.name
        FROM notes_versions AS nv
        LEFT JOIN langs AS l ON l.id = nv.lang_id
        WHERE nv.note_id = ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($note_id);
    while (
        my (
            $id,       $lang_id,  $name,     $p_title,  $p_descr,  $descr,
            $param_01, $param_02, $param_03, $param_04, $param_05, $lang_name
        )
        = $sth->fetchrow_array()
    ) {
        push @versions, {
            lang_id   => $lang_id,
            lang_name => $lang_name,
            note_id   => $note_id,
            id        => $id,
            name      => Util::Renderer::do_escape($name),
            p_title   => Util::Renderer::do_escape($p_title),
            p_descr   => Util::Renderer::do_escape($p_descr),
            descr     => Util::Renderer::do_escape($descr),
            param_01  => Util::Renderer::do_escape($param_01),
            param_02  => Util::Renderer::do_escape($param_02),
            param_03  => Util::Renderer::do_escape($param_03),
            param_04  => Util::Renderer::do_escape($param_04),
            param_05  => Util::Renderer::do_escape($param_05),
        };
    }
    $sth->finish();

    return \@versions;
}

1;
