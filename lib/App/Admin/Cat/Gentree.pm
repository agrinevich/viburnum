package App::Admin::Cat::Gentree;

use strict;
use warnings;

use Const::Fast;

use Util::JobQueue;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app = $args{app};

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );

    my $job = Util::JobQueue::new_job(
        {
            funcname => 'App::Worker::CreateSitemap',
            args     => {
                root_dir  => $app->root_dir,
                log_file  => $app->log_file,
                conf_file => $app->conf_file,
            },
        }
    );
    if ( !$job ) {
        $app->logger->error(q{Failed to create job object});
    }

    my $success = $jqc->insert($job);
    if ( !$success ) {
        $app->logger->error(q{Failed to enqueue job});
    }

    return {
        url => $app->config->{site}->{host} . '/admin/jq',
    };
}

1;
