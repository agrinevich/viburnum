package App::Admin::Note::Updvers;

use strict;
use warnings;

use Util::Renderer;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $id      = $o_params->{id}      || 0;
    my $note_id = $o_params->{note_id} || 0;
    my $name     = $o_params->{name}     // q{};
    my $p_title  = $o_params->{p_title}  // q{};
    my $p_descr  = $o_params->{p_descr}  // q{};
    my $descr    = $o_params->{descr}    // q{};
    my $param_01 = $o_params->{param_01} // q{};
    my $param_02 = $o_params->{param_02} // q{};
    my $param_03 = $o_params->{param_03} // q{};
    my $param_04 = $o_params->{param_04} // q{};
    my $param_05 = $o_params->{param_05} // q{};

    # $name    = $self->do_unescape($name);
    # $p_title = $self->do_unescape($p_title);
    # $p_descr = $self->do_unescape($p_descr);
    # $descr   = $self->do_unescape($descr);

    my $upd = <<'EOF';
        UPDATE notes_versions SET
            name      = ?,
            p_title   = ?,
            p_descr   = ?,
            param_01  = ?,
            param_02  = ?,
            param_03  = ?,
            param_04  = ?,
            param_05  = ?,
            descr     = ?
        WHERE id = ?
EOF
    my $sth = $app->dbh->prepare($upd);
    $sth->execute(
        $name,
        $p_title,
        $p_descr,
        $param_01,
        $param_02,
        $param_03,
        $param_04,
        $param_05,
        $descr,
        $id
    );

    my $host = $app->config->{site}->{host};
    my $url  = $host . q{/admin/note/edit?id=} . $note_id;

    return {
        url => $url,
    };
}

1;
