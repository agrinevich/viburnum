package App::Admin::Good::Fetchimages;

use strict;
use warnings;

use Util::JobQueue;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app = $args{app};
    # my $o_request = $args{o_request};
    # my $o_params = $o_request->parameters();

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );

    my $job = Util::JobQueue::new_job(
        {
            funcname => 'App::Worker::FetchImages',
            args     => {
                root_dir  => $app->root_dir,
                log_file  => $app->log_file,
                conf_file => $app->conf_file,
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
