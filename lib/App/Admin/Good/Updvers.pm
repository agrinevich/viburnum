package App::Admin::Good::Updvers;

use strict;
use warnings;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $id      = $o_params->{id}      || 0;
    my $good_id = $o_params->{good_id} || 0;
    my $name    = $o_params->{name}    // q{};
    my $p_title = $o_params->{p_title} // q{};
    my $p_descr = $o_params->{p_descr} // q{};
    my $descr   = $o_params->{descr}   // q{};

    # $name    = do_unescape($name);
    # $p_title = do_unescape($p_title);
    # $p_descr = do_unescape($p_descr);
    # $descr   = do_unescape($descr);

    my $upd = <<'EOF';
		UPDATE goods_versions SET
            name      = ?,
            p_title   = ?,
            p_descr   = ?,
            descr  = ?
		WHERE id = ?
EOF
    my $sth = $app->dbh->prepare($upd);
    $sth->execute(
        $name,
        $p_title,
        $p_descr,
        $descr,
        $id
    );

    my $host = $app->config->{site}->{host};
    my $url  = $host . q{/admin/good/edit?id=} . $good_id;

    return {
        url => $url,
    };
}

1;
