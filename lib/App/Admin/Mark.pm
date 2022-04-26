package App::Admin::Mark;

use strict;
use warnings;

use Util::Renderer;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $tpl_path = $app->config->{templates}->{path};
    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;

    my $a_marks = _get_marks(
        dbh => $dbh,
    );

    my $list = q{};

    foreach my $h ( @{$a_marks} ) {
        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/mark',
            tpl_name => 'list-item.html',
            h_vars   => {
                id    => $h->{id},
                name  => $h->{name},
                value => $h->{value},
            },
        );
    }

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/mark',
        tpl_name => 'list.html',
        h_vars   => {
            list => $list,
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

sub _get_marks {
    my (%args) = @_;

    my $dbh = $args{dbh};

    my @result = ();

    my $sel = <<'EOF';
        SELECT id, name, value
        FROM global_marks
        ORDER BY name ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $id, $name, $value ) = $sth->fetchrow_array() ) {
        push @result, {
            id    => $id,
            name  => $name,
            value => $value,
        };
    }
    $sth->finish();

    return \@result;
}

1;
