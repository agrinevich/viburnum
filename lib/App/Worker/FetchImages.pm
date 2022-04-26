package App::Worker::FetchImages;

use strict;
use warnings;

use parent qw( TheSchwartz::Worker );
use TheSchwartz::Job;

use Const::Fast;
use File::Fetch;
use Carp qw(croak carp);

use Util::Config;
use Util::Log;
use Util::DB;
use Util::Goods;
use Util::Images;

our $VERSION = '1.1';

const my $PAUSE_SEC    => 2;
const my $QTY_TO_FETCH => 100;

sub work {
    my ( undef, $job ) = @_;

    my %args = @{ $job->arg };

    my $root_dir  = $args{root_dir};
    my $log_file  = $args{log_file};
    my $conf_file = $args{conf_file};

    my $config = Util::Config::get_config(
        # root_dir  => $root_dir,
        # conf_file => $conf_file,
        file => $root_dir . q{/} . $conf_file,
    );

    # my $logger = Util::Log::get_lh(
    #     root_dir => $root_dir,
    #     log_file => $log_file,
    # );

    my $dbh = Util::DB::get_dbh(
        db_name => $config->{mysql}->{db_name},
        db_user => $config->{mysql}->{user},
        db_pass => $config->{mysql}->{pass},
    );

    my $html_path = $config->{data}->{html_path};
    my $img_path  = $config->{data}->{images_path};
    my $img_dir   = $root_dir . $html_path . $img_path;
    my $tmp_dir   = $root_dir . '/tmp';

    my $sel = <<'EOF';
        SELECT g.id, g.sup_id, g.code, gi.id, gi.num, gi.url
        FROM goods AS g
        LEFT JOIN goods_images AS gi ON g.id = gi.good_id
        WHERE g.hidden = 0
        AND gi.path_sm = ""
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    my $i = 0;
    while ( my ( $id, $sup_id, $code, $img_id, $img_num, $img_url ) = $sth->fetchrow_array() ) {
        $i++;
        if ( $i > $QTY_TO_FETCH ) {
            last;
        }

        my $err = _save_image(
            config   => $config,
            good_id  => $id,
            sup_id   => $sup_id,
            code     => $code,
            img_id   => $img_id,
            img_num  => $img_num,
            img_url  => $img_url,
            dbh      => $dbh,
            img_path => $img_path,
            img_dir  => $img_dir,
            tmp_dir  => $tmp_dir,
        );
        if ($err) {
            carp( 'failed: ' . $img_url . q{ - } . $err );
        }
    }
    $sth->finish();

    carp( 'processed images: ' . ( $i - 1 ) );
    $job->completed();

    return;
}

sub _save_image {
    my (%args) = @_;

    my $config   = $args{config};
    my $good_id  = $args{good_id};
    my $sup_id   = $args{sup_id};
    my $code     = $args{code};
    my $img_id   = $args{img_id};
    my $img_url  = $args{img_url};
    my $img_num  = $args{img_num};
    my $dbh      = $args{dbh};
    my $img_path = $args{img_path};
    my $img_dir  = $args{img_dir};
    my $tmp_dir  = $args{tmp_dir};

    #
    # TODO: get file ext from img_url
    #
    my $ext = q{};

    my $img_name = Util::Goods::build_img_name(
        sup_id  => $sup_id,
        code    => $code,
        img_num => $img_num,
        ext     => $ext,
    );

    my $img_path_sm = $img_path . '/sm/' . $img_name;
    my $img_path_la = $img_path . '/la/' . $img_name;

    my $img_file_la = $img_dir . '/la/' . $img_name;
    my $img_file_sm = $img_dir . '/sm/' . $img_name;

    if ( -e $img_file_sm ) {
        return Util::Goods::save_img_path(
            dbh         => $dbh,
            img_id      => $img_id,
            img_path_sm => $img_path_sm,
            img_path_la => $img_path_la,
        );
    }

    sleep $PAUSE_SEC;

    my $ff = File::Fetch->new( uri => $img_url ) || return 'Failed to create File::Fetch object';

    my $file_tmp = $ff->fetch( to => $tmp_dir ) || return $ff->error();

    my $orig_file = $img_dir . q{/} . $img_name;
    rename $file_tmp, $orig_file;

    my $success = Util::Images::scale_image(
        file_src => $orig_file,
        file_dst => $img_file_la,
        width    => $config->{data}->{img_maxw_la},
        height   => $config->{data}->{img_maxh_la},
    );
    if ( !$success ) {
        return 'Failed to scale to large image: ' . $orig_file;
    }

    my $success2 = Util::Images::scale_image(
        file_src => $orig_file,
        file_dst => $img_file_sm,
        width    => $config->{data}->{img_maxw_sm},
        height   => $config->{data}->{img_maxh_sm},
    );
    if ( !$success2 ) {
        return 'Failed to scale to small image: ' . $orig_file;
    }

    my $err = Util::Goods::save_img_path(
        dbh         => $dbh,
        img_id      => $img_id,
        img_path_sm => $img_path_sm,
        img_path_la => $img_path_la,
    );
    if ($err) {
        return $err;
    }

    # first image path duplicate to 'goods' table
    if ( !$img_num ) {
        $dbh->do(
            qq{UPDATE goods SET changed=1, img_path_sm="$img_path_sm", img_path_la="$img_path_la" WHERE id=$good_id},
        );
    }

    unlink $orig_file;

    return;
}

1;
