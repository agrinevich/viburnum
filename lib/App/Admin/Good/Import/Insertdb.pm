package App::Admin::Good::Import::Insertdb;

use strict;
use warnings;

use Const::Fast;
use Class::Load qw(try_load_class is_class_loaded);

our $VERSION = '1.1';

const my %ADDER_CLASS => (
    1 => 'Nikoopt',
);

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();

    my $cat_id    = $o_params->{cat_id} || 0;
    my $sup_id    = $o_params->{sup_id} || 0;
    my $file_name = $o_params->{file}   || q{};

    if ( !$cat_id || !$sup_id || !$file_name ) {
        return {
            body => q{cat, sup, file are required},
        };
    }

    my $root       = $app->root_dir;
    my $host       = $app->config->{site}->{host};
    my $ready_path = $app->config->{data}->{prices_path} . '/ready';
    my $ready_file = $root . $ready_path . q{/} . $file_name;

    my $stored_qty;
    {
        my $class = 'App::Admin::Good::Import::Insert::' . $ADDER_CLASS{$sup_id};

        my ( $rc, $err ) = try_load_class($class);
        if ( !is_class_loaded($class) ) {
            $app->logger->error($err);
            return {
                url => $host . '/admin/good/import?err=' . $err,
            };
        }

        $stored_qty = $class->insert2db(
            app    => $app,
            sup_id => $sup_id,
            cat_id => $cat_id,
            file   => $ready_file,
        );
    }

    unlink $ready_file;

    return {
        url => $host . '/admin/good/import',
    };
}

1;
