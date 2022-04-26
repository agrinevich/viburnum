package App::Admin::Good::Import::Updatedb;

use strict;
use warnings;

use Util::JobQueue;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $file_name = $o_params->{file}   // q{};
    my $sup_id    = $o_params->{sup_id} // 0;

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );

    my $job = Util::JobQueue::new_job(
        {
            funcname => 'App::Worker::UpdGoods',
            args     => {
                root_dir  => $app->root_dir,
                log_file  => $app->log_file,
                conf_file => $app->conf_file,
                file_name => $file_name,
                sup_id    => $sup_id,
            },
        }
    );
    if ( !$job ) {
        $app->logger->info(q{Failed to create job object});
    }

    my $success = $jqc->insert($job);
    if ( !$success ) {
        $app->logger->info(q{Failed to enqueue job});
    }

    return {
        url => $app->config->{site}->{host} . '/admin/jq',
    };
}

1;
