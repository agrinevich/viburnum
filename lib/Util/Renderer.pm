package Util::Renderer;

use strict;
use warnings;

use Const::Fast;
use Carp qw(croak carp);
use HTML::Entities;
use Path::Tiny; # path, spew_utf8
use Text::Xslate qw(mark_raw html_escape);

our $VERSION = '1.1';

const my $ROUND_NUMBER => 0.999999;
const my %MSG_TEXT     => (
    success => 'Success',
    error   => 'Error',
);

sub write_html {
    my ( $h_vars, $h_args ) = @_;

    my $root_dir  = $h_args->{root_dir};
    my $tpl_path  = $h_args->{tpl_path};
    my $tpl_file  = $h_args->{tpl_file};
    my $out_path  = $h_args->{out_path};
    my $out_file  = $h_args->{out_file};
    my $html_path = $h_args->{html_path};
    my $dbh       = $h_args->{dbh};

    my $html = parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => $tpl_file,
        h_vars   => $h_vars,
        dbh      => $dbh,
    );

    my $out_dir = $root_dir . $html_path . $out_path;
    path( $out_dir . q{/} . $out_file )->spew_utf8($html);

    return 1;
}

sub parse_html {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $tpl_name = $args{tpl_name};
    my $dbh      = $args{dbh};
    my $h_vars   = $args{h_vars};

    if ($dbh) {
        my $h_vars_2 = _get_global_marks( dbh => $dbh );
        $h_vars = { %{$h_vars}, %{$h_vars_2} };
    }

    foreach my $k ( keys %{$h_vars} ) {
        $h_vars->{$k} = mark_raw( $h_vars->{$k} );
    }

    my $tx = Text::Xslate->new(
        path        => [ $root_dir . $tpl_path ],
        syntax      => 'TTerse',
        input_layer => ':utf8',
    );

    return $tx->render( $tpl_name, $h_vars ) || croak 'Failed to parse_html';
}

sub build_options {
    my (%args) = @_;

    my $a_items  = $args{items}    // [];
    my $id_sel   = $args{id_sel}   // 0;
    my $root_dir = $args{root_dir} // q{};
    my $tpl_path = $args{tpl_path} // q{};
    my $tpl_file = $args{tpl_file} // q{};

    my $result = q{};
    my %attr   = ( $id_sel => ' selected' );

    foreach my $h ( @{$a_items} ) {
        $h->{attr} = $attr{ $h->{id} // 0 };

        $result .= parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path,
            tpl_name => $tpl_file,
            h_vars   => $h,
        );
    }

    return $result;
}

sub build_msg {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $tpl_name = $args{tpl_name};
    my $msg      = $args{msg};

    return q{} if !$msg;

    my $html = parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => $tpl_name,
        h_vars   => {
            text => $MSG_TEXT{$msg},
        },
    );

    return $html;
}

sub build_paging {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};
    my $qty      = $args{qty};
    my $npp      = $args{npp};
    my $p_cur    = $args{p};
    my $path     = $args{path};

    my $result   = q{};
    my $tpl_name = q{};
    my $suffix   = q{};

    my $p_qty  = int( $qty / $npp + $ROUND_NUMBER );
    my $p_last = $p_qty - 1;
    foreach my $p ( 0 .. $p_last ) {
        if   ( $p == $p_cur ) { $tpl_name = 'paging-item-cur.html'; }
        else                  { $tpl_name = 'paging-item.html'; }

        $suffix = $p ? $p : q{};

        $result .= parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/cat',
            tpl_name => $tpl_name,
            h_vars   => {
                p      => $p,
                num    => ( $p + 1 ),
                path   => $path,
                suffix => $suffix,
            },
        );
    }

    return $result;
}

sub do_escape {
    my ($str) = @_;
    return html_escape($str);
}

sub do_unescape {
    my ($str) = @_;
    return decode_entities($str);
}

sub _get_global_marks {
    my (%args) = @_;

    my $dbh = $args{dbh};
    my %result;

    my $sel = q{SELECT name, value FROM global_marks};
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $name, $value ) = $sth->fetchrow_array() ) {
        $result{$name} = $value;
    }
    $sth->finish();

    return \%result;
}

1;
