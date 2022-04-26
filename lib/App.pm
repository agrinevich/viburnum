package App;

use Moo;
use Class::Load qw(try_load_class is_class_loaded);

use Util::Config;
use Util::DB;
use Util::Log;

our $VERSION = '1.1';

has 'root_dir' => (
    is       => 'ro',
    required => 1,
);

has 'conf_file' => (
    is       => 'ro',
    required => 1,
);

has 'log_file' => (
    is       => 'ro',
    required => 1,
);

has 'config' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return Util::Config::get_config(
            file => $self->root_dir . q{/} . $self->conf_file,
        );
    },
);

has 'logger' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return Util::Log::get_lh(
            root_dir => $self->root_dir,
            log_file => $self->log_file,
        );
    },
);

has 'dbh' => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return Util::DB::get_dbh(
            db_name => $self->config->{mysql}->{db_name},
            db_user => $self->config->{mysql}->{user},
            db_pass => $self->config->{mysql}->{pass},
        );
    },
);

sub require_class {
    my ( $self, %args ) = @_;

    my $path_info      = $args{path_info};
    my $a_path_default = $args{a_path_default} // [ 'admin', 'cat' ];

    my @path_chunks = split m{\/}xms, $path_info;

    # drop empty first chunk
    if ( !length $path_chunks[0] ) {
        shift @path_chunks;
    }

    # cut off /favicon.ico, etc.
    my @clear_chunks = ();
    foreach my $chunk (@path_chunks) {
        $chunk =~ s/\W//xmsg;
        push @clear_chunks, $chunk;
    }

    # default route is 'admin/cat' if no given
    if ( scalar @clear_chunks < 2 ) {
        @clear_chunks = @{$a_path_default};
    }

    my @name_chunks = map { ucfirst; } @clear_chunks;
    my $class_name  = 'App::' . join q{::}, @name_chunks;

    my ( $rc, $err ) = try_load_class($class_name);
    if ($err) {
        $self->logger->error($err);
    }

    return is_class_loaded($class_name) ? $class_name : undef;
}

1;
