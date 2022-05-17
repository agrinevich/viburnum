package App::User::Cart;

use strict;
use warnings;

use Util::Renderer;
use Util::Files;
use Util::Langs;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params  = $o_request->parameters();
    my $lang_nick = $o_params->{l} // q{};

    my $sess       = $app->session;
    my $dbh        = $app->dbh;
    my $root_dir   = $app->root_dir;
    my $site_host  = $app->config->{site}->{host};
    my $tpl_path   = $app->config->{templates}->{path_f};
    my $bread_path = $app->config->{data}->{bread_path};
    my $navi_path  = $app->config->{data}->{navi_path};
    my $html_path  = $app->config->{data}->{html_path};

    my $page_path = q{}; # we are using root user layout

    my $h_lang = Util::Langs::get_lang(
        dbh       => $dbh,
        lang_nick => $lang_nick,
    );

    # TODO: _delete_expired();

    my $a_items = get_items(
        dbh     => $dbh,
        sess_id => $sess->sess_id,
        lang_id => $h_lang->{lang_id},
    );
    my $list = q{};
    foreach my $h ( @{$a_items} ) {
        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/user',
            tpl_name => 'cart-item.html',
            h_vars   => {
                id    => $h->{id},
                qty   => $h->{qty},
                price => $h->{price},
                name  => $h->{name},
            },
        );
    }

    my $tpl_name = sprintf 'cart%s.html', $h_lang->{lang_suffix};
    my $tpl_file = $root_dir . $tpl_path . '/user/' . $tpl_name;

    if ( !-e $tpl_file ) {
        # create tpl from default tpl
        my $tpl_file_primary = $root_dir . $tpl_path . '/user/cart.html';
        Util::Files::copy_file(
            src => $tpl_file_primary,
            dst => $tpl_file,
        );
    }

    my $h_marks = {};

    $h_marks->{page_main} = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/user',
        tpl_name => $tpl_name,
        h_vars   => {
            lang_nick => $h_lang->{lang_nick},
            list      => $list,
        },
    );

    # lang links for this page
    my $a_langs    = Util::Langs::get_langs( dbh => $dbh );
    my $h_langhref = Util::Langs::build_hrefs(
        a_langs       => $a_langs,
        lang_path_cur => $h_lang->{lang_path},
        base_path     => q{},
        app_path      => $o_request->path_info(),
        root_dir      => $root_dir,
        site_host     => $site_host,
        tpl_path      => $tpl_path,
    );
    $h_marks->{lang_metatags} = $h_langhref->{metatags};
    $h_marks->{lang_links}    = $h_langhref->{links};

    my $page = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $html_path . $h_lang->{lang_path} . $page_path,
        tpl_name => 'layout-user.html',
        h_vars   => $h_marks,
    );

    return {
        body => $page,
    };
}

sub get_items {
    my (%args) = @_;

    my $dbh     = $args{dbh};
    my $sess_id = $args{sess_id};
    my $lang_id = $args{lang_id};

    my @result = ();

    my $sel = <<'EOF';
        SELECT sc.item_id, sc.item_qty, sc.item_price, nv.name
        FROM sess_cart AS sc
        LEFT JOIN notes_versions AS nv
            ON sc.item_id = nv.note_id
        WHERE sc.sess_id = ?
        AND nv.lang_id = ?
        ORDER BY nv.name ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute( $sess_id, $lang_id );
    while ( my ( $id, $qty, $price, $name ) = $sth->fetchrow_array() ) {
        push @result, {
            id    => $id,
            qty   => $qty,
            price => $price,
            name  => $name,
        };
    }
    $sth->finish();

    return \@result;
}

# sub _delete_expired {
#     my (%args) = @_;

#     my $dbh      = $args{dbh};
#     my $ttl_days = $args{ttl_days};

#     return if !$ttl_days;

#     my @ids = ();

#     my $sel = <<'EOF';
#         SELECT id
#         FROM notes
#         WHERE page_id = ?
#         AND is_ext = 1
#         AND TO_DAYS(NOW()) - TO_DAYS(add_dt) > ?
# EOF
#     my $sth = $dbh->prepare($sel);
#     $sth->execute( $page_id, $ttl_days );
#     while ( my ($id) = $sth->fetchrow_array() ) {
#         push @ids, $id;
#     }
#     $sth->finish();

#     foreach my $note_id (@ids) {
#         $dbh->do("DELETE FROM notes_versions WHERE note_id = $note_id");
#         $dbh->do("DELETE FROM notes_images WHERE note_id = $note_id");
#         $dbh->do("DELETE FROM notes WHERE id = $note_id");
#     }

#     return;
# }

1;
