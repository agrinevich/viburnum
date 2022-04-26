package App::Worker::UpdGoods;

use strict;
use warnings;

use parent qw( TheSchwartz::Worker );
use TheSchwartz::Job;

use Const::Fast;
use Carp qw(croak carp);
use Class::Load qw(try_load_class is_class_loaded);

use Util::Config;
use Util::Log;
use Util::DB;

our $VERSION = '1.1';

const my %UPDATER_CLASS => (
    1 => 'Nikoopt',
);

sub work {
    my ( undef, $job ) = @_;

    my %args = @{ $job->arg };

    my $root_dir  = $args{root_dir};
    my $log_file  = $args{log_file};
    my $conf_file = $args{conf_file};
    my $file_name = $args{file_name};
    my $sup_id    = $args{sup_id};

    my $config = Util::Config::get_config(
        # root_dir  => $root_dir,
        # conf_file => $conf_file,
        file => $root_dir . q{/} . $conf_file,
    );

    my $logger = Util::Log::get_lh(
        root_dir => $root_dir,
        log_file => $log_file,
    );

    my $dbh = Util::DB::get_dbh(
        db_name => $config->{mysql}->{db_name},
        db_user => $config->{mysql}->{user},
        db_pass => $config->{mysql}->{pass},
    );

    my $root     = $root_dir;
    my $raw_path = $config->{data}->{prices_path} . '/raw';
    my $raw_file = $root . $raw_path . q{/} . $file_name;

    my $class = 'App::Admin::Good::Import::Update::' . $UPDATER_CLASS{$sup_id};

    my ( $rc, $err ) = try_load_class($class);
    if ( !is_class_loaded($class) ) {
        # $logger->error($err);
        carp($err);
        $job->failed($err);
        return;
    }

    my $upd_qty = $class->update2db(
        file     => $raw_file,
        sup_id   => $sup_id,
        config   => $config,
        logger   => $logger,
        dbh      => $dbh,
        root_dir => $root_dir,
    );
    carp("updated: $upd_qty");

    unlink $raw_file;

    $job->completed();
    return;
}

1;
