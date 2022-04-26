package App::Admin::Good::Import::Splitrawtocsv;

use strict;
use warnings;

use Const::Fast;
use Class::Load qw(try_load_class is_class_loaded);

our $VERSION = '1.1';

const my %SPLITTER_CLASS => (
    1 => 'Nikoopt',
);

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $file_name = $o_params->{file}   // q{};
    my $sup_id    = $o_params->{sup_id} // 0;

    my $root     = $app->root_dir;
    my $host     = $app->config->{site}->{host};
    my $raw_path = $app->config->{data}->{prices_path} . '/raw';
    my $raw_file = $root . $raw_path . q{/} . $file_name;

    my $split_result = q{};
    {
        my $class = 'App::Admin::Good::Import::Split::' . $SPLITTER_CLASS{$sup_id};

        my ( $rc, $err ) = try_load_class($class);
        if ( !is_class_loaded($class) ) {
            $app->logger->error($err);
            return {
                url => $host . '/admin/good/import?err=' . $err,
            };
        }

        $class->split2csv(
            app    => $app,
            sup_id => $sup_id,
            file   => $raw_file,
        );
    }

    unlink $raw_file;

    return {
        url => $host . '/admin/good/import',
    };
}

1;
