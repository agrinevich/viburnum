package App::Admin::Note::Add;

use strict;
use warnings;

use Util::Langs;
use Util::Notes;
use Util::Config;
use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $descr     = $o_params->{descr};
    my $name      = $o_params->{name};
    my $page_name = $o_params->{page_name};
    my $page_id   = $o_params->{page_id} || 0;

    my $base_path = Util::Tree::page_path(
        dbh     => $app->dbh,
        page_id => $page_id,
    );

    my $mode_config = Util::Config::get_mode_config(
        root_dir  => $app->root_dir,
        html_path => $app->config->{data}->{html_path},
        page_id   => $page_id,
        base_path => $base_path,
        mode_name => 'note',
    );
    my $skin = $mode_config->{note}->{skin};

    $app->dbh->do("INSERT INTO notes (page_id) VALUES ($page_id)");

    my $sel = 'SELECT LAST_INSERT_ID()';
    my $sth = $app->dbh->prepare($sel);
    $sth->execute;
    my ($note_id) = $sth->fetchrow_array();
    $sth->finish;

    my $nick = Util::Notes::build_nick(
        name    => $name,
        note_id => $note_id,
    );
    $app->dbh->do("UPDATE notes SET nick = \"$nick\" WHERE id = $note_id");

    my $p_title = $name;

    # Here we adding same texts for all lang versions
    # Later you can edit non-primary lang versions
    my $lang_suffix = q{};

    my $p_descr = Util::Notes::build_p_descr(
        page_name   => $page_name,
        note_name   => $name,
        lang_suffix => $lang_suffix,
        tpl_path    => $app->config->{templates}->{path_f},
        root_dir    => $app->root_dir,
        skin        => $skin,
    );

    my $a_langs = Util::Langs::get_langs( dbh => $app->dbh );
    my $ins2    = <<'EOF2';
        INSERT INTO notes_versions
        (note_id, lang_id, name, descr, p_title, p_descr)
        VALUES
        (?, ?, ?, ?, ?, ?)
EOF2
    my $sth2 = $app->dbh->prepare($ins2);
    foreach my $h_lang ( @{$a_langs} ) {
        $sth2->execute( $note_id, $h_lang->{lang_id}, $name, $descr, $p_title, $p_descr );
    }

    my $host = $app->config->{site}->{host};
    my $url  = $host . '/admin/note/edit?id=' . $note_id;

    return {
        url => $url,
    };
}

1;
