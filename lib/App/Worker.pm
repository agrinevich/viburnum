package App::Worker;

use Moo;
extends 'App';

use Const::Fast;
use Carp qw(croak carp);
use Class::Load qw(try_load_class is_class_loaded);

use Util::JobQueue;

our $VERSION = '1.1';

const my @_WORKERS => qw(
    create_pages
    create_shop
    create_notes
    create_sitemap
    upd_goods
    fetch_images
    send_mail
);

sub run {
    my ($self) = @_;

    my $jqc = Util::JobQueue::new_client( dbh => $self->dbh );

    foreach my $worker_nick (@_WORKERS) {
        my @orig_chunks  = split m{_}xms, $worker_nick;
        my @nick_chunks  = map { ucfirst; } @orig_chunks;
        my $worker_name  = join q{}, @nick_chunks;
        my $worker_class = 'App::Worker::' . $worker_name;

        my ( $rc, $err ) = try_load_class($worker_class);
        if ( !is_class_loaded($worker_class) ) {
            $self->logger->error("Failed to load '$worker_class': $err");
            next;
        }

        $jqc->can_do($worker_class);
        $self->logger->info( $worker_class . q{ registered} );
    }

    $self->logger->info(q{JobQueue start});
    $jqc->work();
    return;
}

1;
