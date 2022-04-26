package Util::Log;

use strict;
use warnings;

use Log::Log4perl qw(:easy);

our $VERSION = '1.1';

sub get_lh {
    my (%args) = @_;

    my $root_dir = $args{root_dir};
    my $log_file = $args{log_file};

    my $permissions = '0755';
    my $log_dir     = $root_dir . '/log';

    if ( !-d $log_dir ) {
        mkdir $log_dir, oct $permissions;
    }

    my $file = $log_dir . q{/} . $log_file;

    Log::Log4perl->easy_init(
        {
            level => $DEBUG,
            file  => ">>$file",
        }
    );

    return Log::Log4perl->get_logger();
}

1;
