package App::Admin::Templ::Update;

use strict;
use warnings;

use Util::Files;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $fdir     = $o_params->{fdir} || q{};
    my $fname    = $o_params->{fname} || q{};
    my $fcode    = $o_params->{fcode} || q{};

    Util::Files::write_file(
        file => $fdir . q{/} . $fname,
        body => $fcode,
    );

    return {
        url => $app->config->{site}->{host} . "/admin/templ?fdir=$fdir&fname=$fname",
    };
}

1;
