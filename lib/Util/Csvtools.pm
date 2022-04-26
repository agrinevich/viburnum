package Util::Csvtools;

use strict;
use warnings;
# use utf8;
# use autodie qw(open close);

use English qw( -no_match_vars );
use Carp qw(croak carp);
use Text::CSV;
use Text::Trim; # trim

our $VERSION = '1.1';

sub read_csv {
    my ( $h_args, $h_params ) = @_;

    my $file = $h_args->{file};
    my $mode = $h_args->{mode};

    my $csv = Text::CSV->new($h_params);
    # warn "csv object created\n";

    my @rows = ();
    open my $fh, $mode, $file or croak $OS_ERROR;
    while ( my $a_row = $csv->getline($fh) ) {
        # if ( !$a_row ) { warn 'errstr=' . $csv->error_diag() . "\n"; }
        push @rows, $a_row;
    }
    # no autodie;
    close $fh or croak $OS_ERROR;

    # warn 'rowsqty=' . scalar @rows . "\n";
    return \@rows;
}

sub write_csv {
    my ( $a_rows, $file ) = @_;

    my $csv = Text::CSV->new(
        {
            binary           => 1,
            auto_diag        => 1,
            eol              => qq{\n},
            sep_char         => q{;},
            escape_char      => q{\\},
            blank_is_undef   => 1,
            empty_is_undef   => 1,
            allow_whitespace => 1,
            # quote_char       => q{'},
        }
    );

    open my $fh, '>:encoding(UTF-8)', $file or croak $OS_ERROR;
    foreach my $a_row_values ( @{$a_rows} ) {
        $csv->print( $fh, $a_row_values );
    }
    # no autodie;
    close $fh or croak $OS_ERROR;

    return;
}

sub row_values {
    my ( $h, $a_row ) = @_;

    # get values by row indexes
    my $code    = $a_row->[ $h->{code_idx} ];
    my $name    = $a_row->[ $h->{name_idx} ];
    my $price   = $a_row->[ $h->{price_idx} ] // 0;
    my $cat     = $a_row->[ $h->{cat_idx} ];
    my $descr   = $a_row->[ $h->{descr_idx} ];
    my $size    = $a_row->[ $h->{size_idx} ];
    my $color   = $a_row->[ $h->{color_idx} ];
    my $textile = $a_row->[ $h->{textile_idx} ];
    my $images  = $a_row->[ $h->{images_idx} ];

    # process values
    $price =~ s/[\,\-]/[.]/mxsg;
    $price =~ s/[^\d.]//mxsg;
    $code    = trim($code);
    $name    = trim($name);
    $cat     = trim($cat);
    $descr   = trim($descr);
    $size    = trim($size);
    $color   = trim($color);
    $textile = trim($textile);
    $images  = trim($images);

    return {
        code    => $code,
        name    => $name,
        price   => $price,
        cat     => $cat,
        descr   => $descr,
        size    => $size,
        color   => $color,
        textile => $textile,
        images  => $images,
    };
}

1;
