package App::Admin::Good::Import::Split::Nikoopt;

use strict;
use warnings;

use Const::Fast;

use Util::Files;
use Util::Csvtools;
use Util::Goods;

our $VERSION = '1.1';

const my $FILE_NAME_MAX_LENGTH => 64;

#
# Before uploading price list do manually:
# 1) replace cyrillic cat names with english names
# 2) re-save input file with UTF8 encoding
#

sub split2csv {
    my ( undef, %args ) = @_;

    my $app        = $args{app};
    my $sup_id     = $args{sup_id};
    my $input_file = $args{file};
    # warn 'ifile=' . $input_file . "\n";

    my $a_rows = Util::Csvtools::read_csv(
        {
            file => $input_file,
            mode => '<',
            # mode => '<:encoding(UTF-8)',
        },
        {
            binary                => 1,
            auto_diag             => 1,
            diag_verbose          => 1,
            eol                   => qq{\n},
            sep_char              => q{;},
            blank_is_undef        => 1,
            empty_is_undef        => 1,
            allow_whitespace      => 1,
            allow_loose_quotes    => 1,
            allow_unquoted_escape => 1,
            # escape_char      => $escape_char,
            # quote_char       => $quote_char,
        }
    );
    # warn 'rows_qty=' . scalar @{$a_rows} . "\n";

    # get columns indexes from config
    my $section = 'supplier_' . $sup_id;
    my $h_sup   = {
        sup_id      => $sup_id,
        code_idx    => $app->config->{$section}->{code_idx},
        name_idx    => $app->config->{$section}->{name_idx},
        cat_idx     => $app->config->{$section}->{cat_idx},
        descr_idx   => $app->config->{$section}->{descr_idx},
        size_idx    => $app->config->{$section}->{size_idx},
        color_idx   => $app->config->{$section}->{color_idx},
        textile_idx => $app->config->{$section}->{textile_idx},
        price_idx   => $app->config->{$section}->{price_idx},
        images_idx  => $app->config->{$section}->{images_idx},
    };

    # group rows by category
    my %cat_rows = ();
    my $i        = 0;
    foreach my $a_row ( @{$a_rows} ) {
        my $h_row = Util::Csvtools::row_values( $h_sup, $a_row );
        next if !$h_row->{code} || !$h_row->{name};
        next if $h_row->{price} !~ /\d+/mxs;
        $i++;

        if ( exists $cat_rows{ $h_row->{cat} } ) {
            push @{ $cat_rows{ $h_row->{cat} } }, $a_row;
        }
        else {
            $cat_rows{ $h_row->{cat} } = [$a_row];
        }
    }
    # warn "i=$i\n";

    # write rows to file by category
    my $root       = $app->root_dir;
    my $ready_path = $app->config->{data}->{prices_path} . '/ready';
    my $dst_dir    = $root . $ready_path;
    if ( !-d $dst_dir ) {
        Util::Files::make_path( path => $dst_dir );
    }
    my @ready_files = ();
    foreach my $cat ( keys %cat_rows ) {
        my $file_name = $cat . '.csv';
        my $file      = $dst_dir . q{/} . $file_name;
        # warn "file=$file\n";

        # FIXME: catch write error
        Util::Csvtools::write_csv( $cat_rows{$cat}, $file );

        push @ready_files, $file_name;
    }

    Util::Goods::delete_goods_by_sup(
        app    => $app,
        sup_id => $sup_id,
    );

    # return join qq{<br>\n}, @ready_files;
    return scalar @ready_files;
}

1;
