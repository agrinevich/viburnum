package App::Worker;

use Moo;
extends 'App';

use Const::Fast;
use Carp qw(croak carp);
use Class::Load qw(try_load_class is_class_loaded);

use Util::JobQueue;
use Util::Files;

our $VERSION = '1.1';

sub run {
    my ($self) = @_;

    my $jqc = Util::JobQueue::new_client( dbh => $self->dbh );

    my $a_files = Util::Files::get_files( dir => $self->root_dir . '/lib/App/Worker' );

    foreach my $h_file ( @{$a_files} ) {
        my ( $worker_name, undef ) = split /[.]/, $h_file->{name};
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
