package App::Admin::Good::Edit;

use strict;
use warnings;

use Util::Renderer;
use Util::Tree;
# use Util::Langs;
use Util::Goods;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;

    my $tpl_path = $app->config->{templates}->{path};
    my $root_dir = $app->root_dir;
    my $dbh      = $app->dbh;

    # my $lang_options = q{};
    # my $a_langs      = Util::Langs::get_langs(
    #     dbh => $dbh,
    # );

    my $h_properties = _get_properties(
        id  => $id,
        dbh => $dbh,
    );

    my $cat_options = q{};
    {
        my $shop_root_id = Util::Tree::find_shop_root( dbh => $dbh );

        my %cat_binded = ();
        my $sel2       = 'SELECT cat_id FROM goods_categories WHERE good_id = ?';
        my $sth2       = $dbh->prepare($sel2);
        $sth2->execute($id);
        while ( my ($cat_id) = $sth2->fetchrow_array() ) {
            $cat_binded{$cat_id} = 1;
        }
        $sth2->finish();

        $cat_options = Util::Tree::build_tree(
            {
                dbh        => $dbh,
                root_dir   => $root_dir,
                tpl_path   => $tpl_path,
                tpl_name   => 'option',
                parent_id  => $shop_root_id,
                level      => 0,
                h_selected => {%cat_binded},
            }
        );
    }

    my $offers = q{};
    {
        my $a_offers = Util::Goods::offers(
            dbh     => $dbh,
            good_id => $id,
        );

        foreach my $h ( @{$a_offers} ) {
            $offers .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'edit-offer.html',
                h_vars   => $h,
            );
        }
    }

    my $versions = q{};
    {
        my $a_versions = _get_versions(
            dbh     => $dbh,
            good_id => $id,
        );
        foreach my $h ( @{$a_versions} ) {
            # $h->{lang_options} = $self->lang_list( $h->{lang_id} );

            $versions .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path . '/good',
                tpl_name => 'edit-version.html',
                h_vars   => $h,
            );
        }
    }

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/good',
        tpl_name => 'edit.html',
        h_vars   => {
            # lang_options => $lang_options,
            cat_options => $cat_options,
            offers      => $offers,
            versions    => $versions,
            %{$h_properties},
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

sub _get_properties {
    my (%args) = @_;

    my $dbh = $args{dbh};
    my $id  = $args{id};

    my $sel = <<'EOF';
        SELECT g.hidden, g.code, g.sup_id, g.name, g.nick
        FROM goods AS g
        WHERE g.id = ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($id);
    my ( $hidden, $code, $sup_id, $name, $nick ) = $sth->fetchrow_array();
    $sth->finish();

    return {
        id     => $id,
        hidden => $hidden,
        code   => $code,
        sup_id => $sup_id,
        name   => Util::Renderer::do_escape($name),
        nick   => $nick,
    };
}

sub _get_versions {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $good_id = $args{good_id};

    my @versions = ();

    my $sel = <<'EOF';
        SELECT
            gv.id, gv.lang_id, gv.name, gv.p_title, gv.p_descr, gv.descr,
            l.name
        FROM goods_versions AS gv
        LEFT JOIN langs AS l
            ON l.id = gv.lang_id
        WHERE gv.good_id = ?
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute($good_id);
    while ( my ( $id, $lang_id, $name, $p_title, $p_descr, $descr, $lang_name )
        = $sth->fetchrow_array() ) {
        push @versions, {
            lang_id   => $lang_id,
            lang_name => $lang_name,
            good_id   => $good_id,
            id        => $id,
            name      => Util::Renderer::do_escape($name),
            p_title   => Util::Renderer::do_escape($p_title),
            p_descr   => Util::Renderer::do_escape($p_descr),
            descr     => Util::Renderer::do_escape($descr),
        };
    }
    $sth->finish();

    return \@versions;
}

1;
