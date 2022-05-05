package Util::Langs;

use strict;
use warnings;

use Util::Renderer;

our $VERSION = '1.1';

sub get_langs {
    my (%args) = @_;

    my $dbh = $args{dbh};

    my @result = ();

    my $sel = <<'EOF';
        SELECT id, name, nick, isocode
        FROM langs
        ORDER BY id ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $id, $name, $nick, $isocode ) = $sth->fetchrow_array() ) {
        my $lang_path   = q{};
        my $lang_suffix = q{};
        if ( length $nick ) {
            $lang_path   = q{/} . $nick;
            $lang_suffix = q{-} . $nick;
        }
        push @result, {
            lang_id      => $id,
            lang_name    => $name,
            lang_nick    => $nick,
            lang_isocode => $isocode,
            lang_path    => $lang_path,
            lang_suffix  => $lang_suffix,
        };
    }
    $sth->finish();

    return \@result;
}

sub get_lang {
    my (%args) = @_;

    my $dbh          = $args{dbh};
    my $lang_id      = $args{lang_id};
    my $lang_nick    = $args{lang_nick};
    my $lang_isocode = $args{lang_isocode};

    my ( $id, $name, $nick, $isocode );

    if ($lang_id) {
        my $sel = 'SELECT name, nick, isocode FROM langs WHERE id = ?';
        my $sth = $dbh->prepare($sel);
        $sth->execute($lang_id);
        ( $name, $nick, $isocode ) = $sth->fetchrow_array();
        $sth->finish();

        $id = $lang_id;
    }
    elsif ($lang_isocode) {
        my $sel = 'SELECT id, name, nick FROM langs WHERE isocode = ?';
        my $sth = $dbh->prepare($sel);
        $sth->execute($lang_isocode);
        ( $id, $name, $nick ) = $sth->fetchrow_array();
        $sth->finish();

        $isocode = $lang_isocode;
    }
    else {
        my $sel = 'SELECT id, name, isocode FROM langs WHERE nick = ?';
        my $sth = $dbh->prepare($sel);
        $sth->execute($lang_nick);
        ( $id, $name, $isocode ) = $sth->fetchrow_array();
        $sth->finish();

        $nick = $lang_nick;
    }

    # fall back to default lang if lang not found
    if ( !$id || !$name || !$isocode ) {
        $id = 1;

        my $sel = 'SELECT name, nick, isocode FROM langs WHERE id = 1';
        my $sth = $dbh->prepare($sel);
        $sth->execute();
        ( $name, $nick, $isocode ) = $sth->fetchrow_array();
        $sth->finish();
    }

    my $lang_suffix = q{};
    my $lang_path   = q{};
    if ( length $nick ) {
        $lang_suffix = q{-} . $nick;
        $lang_path   = q{/} . $nick;
    }

    return {
        lang_id      => $id,
        lang_name    => $name,
        lang_nick    => $nick,
        lang_isocode => $isocode,
        lang_path    => $lang_path,
        lang_suffix  => $lang_suffix,
    };
}

sub build_hrefs {
    my (%args) = @_;

    my $base_path    = $args{base_path};
    my $app_path     = $args{app_path};
    my $site_host    = $args{site_host};
    my $root_dir     = $args{root_dir};
    my $tpl_path     = $args{tpl_path};
    my $tpl_path_gmi = $args{tpl_path_gmi};
    my $a_langs      = $args{a_langs};

    my $metatags  = q{};
    my $links     = q{};
    my $maphrefs  = q{};
    my $gmi_links = q{};

    foreach my $h_lang ( @{$a_langs} ) {
        my $lang_isocode = $h_lang->{lang_isocode};
        my $lang_name    = $h_lang->{lang_name};
        my $lang_nick    = $h_lang->{lang_nick};
        my $lang_path    = $h_lang->{lang_path};

        $metatags .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/lang',
            tpl_name => 'metatag.html',
            h_vars   => {
                hreflang  => $lang_isocode,
                site_host => $site_host,
                path      => $lang_path . $base_path,
            },
        );

        my $link_path;
        if   ($app_path) { $link_path = $app_path . '?l=' . $lang_nick; }
        else             { $link_path = $lang_path . $base_path; }
        $links .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/lang',
            tpl_name => 'link.html',
            h_vars   => {
                lang_name => $lang_name,
                site_host => $site_host,
                path      => $link_path,
            },
        );

        if ($tpl_path_gmi) {
            $gmi_links .= Util::Renderer::parse_html(
                root_dir => $root_dir,
                tpl_path => $tpl_path_gmi . '/lang',
                tpl_name => 'link.gmi',
                h_vars   => {
                    lang_name => $lang_name,
                    path      => $link_path,
                },
            );
        }

        $maphrefs .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/lang',
            tpl_name => 'maphref.html',
            h_vars   => {
                hreflang  => $lang_isocode,
                site_host => $site_host,
                path      => $lang_path . $base_path,
            },
        );
    }

    return {
        metatags  => $metatags,
        links     => $links,
        maphrefs  => $maphrefs,
        gmi_links => $gmi_links,
    };
}

1;
