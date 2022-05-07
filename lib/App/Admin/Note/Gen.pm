package App::Admin::Note::Gen;

use strict;
use warnings;

use Const::Fast;

use Util::JobQueue;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};
    my $o_params  = $o_request->parameters();
    my $page_id   = $o_params->{page_id} || 0;

    my $jqc = Util::JobQueue::new_client( dbh => $app->dbh );

    my $job = Util::JobQueue::new_job(
        {
            funcname => 'App::Worker::CreateNotes',
            args     => {
                root_dir  => $app->root_dir,
                log_file  => $app->log_file,
                conf_file => $app->conf_file,
                page_id   => $page_id,
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
