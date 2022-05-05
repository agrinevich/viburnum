package Util::Texter;

use strict;
use warnings;
use utf8;

use Const::Fast;
use HTML::Strip;
use Encode qw(decode encode);

our $VERSION = '1.1';

const my $META_DESCR_MAX_LENGTH => 160;
const my $DIR_NAME_MAX_LENGTH   => 32;

# sub cat_p_title {
# 	my ( $class, $cat_bread ) = @_;

# 	my $hs       = HTML::Strip->new();
# 	my $cat_text = $hs->parse($cat_bread);
# 	$hs->eof;

# 	$cat_text =~ s/>//g;
# 	$cat_text =~ s/\s+/ /g;

# 	return $cat_text;
# }

# sub cat_p_descr {
# 	my ( $class, $p_title ) = @_;

# 	return 'Купить в интернет-магазине ' . $p_title;
# }

# sub cat_nick {
# 	my ( $class, $id, $name ) = @_;

# 	my $nick = translit($name);

# 	$nick =~ s/[ _]+/-/g;
# 	$nick =~ s/[^\w\d\-]//g;
# 	$nick =~ s/_+/_/g;
# 	$nick =~ s/^_+//xms;
# 	$nick =~ s/_+$//xms;
# 	$nick = lc $nick;
# 	$nick = substr $nick, 0, $DIR_NAME_MAX_LENGTH;
# 	$nick .= q{-} . $id;

# 	#
# 	# FIXME: check nick is unique for this parent!
# 	#

# 	return $nick;
# }

# sub cat_image {
# 	my ( $class, %args ) = @_;

# 	my $id          = $args{id};
# 	my $root_dir    = $args{root_dir};
# 	my $html_path   = $args{html_path};
# 	my $images_path = $args{images_path};

# 	my $img_name = $id . q{.jpg};
# 	my $img_path = $images_path . q{/cat/} . $img_name;
# 	my $file     = $root_dir . $html_path . $img_path;

# 	return $img_path if -e $file;

# 	return $images_path . q{/cat/default.jpg};
# }

# sub good_img_first {
# 	my ( $class, %args ) = @_;

# 	my $image_name = $class->good_img_name( $args{sup_id}, $args{code} );

# 	my $img_path_sm = good_img_path(
# 		image_name => $image_name,
# 		image_type => 'sm',
# 		%args,
# 	);

# 	my $img_path_la = good_img_path(
# 		image_name => $image_name,
# 		image_type => 'la',
# 		%args,
# 	);

# 	return ( $img_path_sm, $img_path_la );
# }

# sub good_img_path {
# 	my (%args) = @_;

# 	my $root_dir    = $args{root_dir};
# 	my $html_path   = $args{html_path};
# 	my $images_path = $args{images_path};
# 	my $image_name  = $args{image_name};
# 	my $image_type  = $args{image_type};

# 	my $img_path = "$images_path/$image_type/default.jpg";

# 	my $images_dir = $root_dir . $html_path . $images_path . "/$image_type";
# 	my $file       = $images_dir . q{/} . $image_name;
# 	if ( -e $file ) {
# 		$img_path = "$images_path/$image_type/$image_name";
# 	}

# 	return $img_path;
# }

sub html2gmi {
    my (%args) = @_;

    my $str = $args{str};

    # replace h1, h2, h3 with #, ##, ###
    $str =~ s/<h1>/\#/g;
    $str =~ s/<\/h1>//g;

    $str =~ s/<h2>/\#\#/g;
    $str =~ s/<\/h2>//g;

    $str =~ s/<h3>/\#\#\#/g;
    $str =~ s/<\/h3>//g;

    # replace li with *
    $str =~ s/<li>/\*/g;
    $str =~ s/<\/li>//g;

    my $hs     = HTML::Strip->new();
    my $result = $hs->parse($str);
    $hs->eof;

    $result =~ s/[\s\t]+\n/\n/g;
    $result =~ s/\n+/\n/g;

    return $result;
}

sub cut_phrase {
    my ( $str, $max_length ) = @_;

    my $result = q{};
    my $separ  = q{};
    my @words  = split / /, $str;

    foreach my $word (@words) {
        if ( length $result . $separ . $word > $max_length ) {
            last;
        }
        $result .= $separ . $word;
        $separ = q{ };
        # last if length $result > 200;
    }

    return $result;
}

sub translit {
    my (%args) = @_;

    my $skip_decode = $args{skip_decode};
    my $input       = $args{input};

    my $text = q{};
    if ($skip_decode) {
        $text = $input;
    }
    else {
        $text = decode( 'UTF-8', $input );
    }

    $text =~ s/А/A/g;
    $text =~ s/а/a/g;
    $text =~ s/Б/B/g;
    $text =~ s/б/b/g;
    $text =~ s/В/V/g;
    $text =~ s/в/v/g;
    $text =~ s/Г/G/g;
    $text =~ s/Ґ/G/g;   # ukr
    $text =~ s/г/g/g;
    $text =~ s/ґ/g/g;   # ukr
    $text =~ s/Д/D/g;
    $text =~ s/д/d/g;
    $text =~ s/Е/E/g;
    $text =~ s/Є/E/g;   # ukr
    $text =~ s/е/e/g;
    $text =~ s/є/e/g;   # ukr
    $text =~ s/Ё/E/g;
    $text =~ s/ё/e/g;
    $text =~ s/Ж/Zh/g;
    $text =~ s/ж/zh/g;
    $text =~ s/З/Z/g;
    $text =~ s/з/z/g;
    $text =~ s/И/I/g;
    $text =~ s/І/I/g;   # ukr
    $text =~ s/Ї/I/g;   # ukr
    $text =~ s/и/i/g;
    $text =~ s/і/i/g;   # ukr
    $text =~ s/ї/i/g;   # ukr
    $text =~ s/Й/Y/g;
    $text =~ s/й/y/g;
    $text =~ s/К/K/g;
    $text =~ s/к/k/g;
    $text =~ s/Л/L/g;
    $text =~ s/л/l/g;
    $text =~ s/М/M/g;
    $text =~ s/м/m/g;
    $text =~ s/Н/N/g;
    $text =~ s/н/n/g;
    $text =~ s/О/O/g;
    $text =~ s/о/o/g;
    $text =~ s/П/P/g;
    $text =~ s/п/p/g;
    $text =~ s/Р/R/g;
    $text =~ s/р/r/g;
    $text =~ s/С/S/g;
    $text =~ s/с/s/g;
    $text =~ s/Т/T/g;
    $text =~ s/т/t/g;
    $text =~ s/У/U/g;
    $text =~ s/у/u/g;
    $text =~ s/Ф/F/g;
    $text =~ s/ф/f/g;
    $text =~ s/Х/Kh/g;
    $text =~ s/х/kh/g;
    $text =~ s/Ц/C/g;
    $text =~ s/ц/c/g;
    $text =~ s/Ч/Ch/g;
    $text =~ s/ч/ch/g;
    $text =~ s/Ш/Sh/g;
    $text =~ s/ш/sh/g;
    $text =~ s/Щ/Shch/g;
    $text =~ s/щ/shch/g;
    $text =~ s/Ь//g;
    $text =~ s/ь//g;
    $text =~ s/Ы/Y/g;
    $text =~ s/ы/y/g;
    $text =~ s/Ъ//g;
    $text =~ s/ъ//g;
    $text =~ s/Э/E/g;
    $text =~ s/э/e/g;
    $text =~ s/Ю/Yu/g;
    $text =~ s/ю/yu/g;
    $text =~ s/Я/Ya/g;
    $text =~ s/я/ya/g;

    return $text;
}

1;
