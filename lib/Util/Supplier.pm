package Util::Supplier;

use strict;
use warnings;

our $VERSION = '1.1';

my %SUP_CACHE = ();

sub list {
    my (%args) = @_;

    my $dbh = $args{dbh};

    my @result = ();

    my $sel = <<'EOF';
        SELECT id, name
        FROM suppliers
        ORDER BY id ASC
EOF
    my $sth = $dbh->prepare($sel);
    $sth->execute();
    while ( my ( $id, $name ) = $sth->fetchrow_array() ) {
        my $a_disp_points = _dispatch_points(
            dbh    => $dbh,
            sup_id => $id,
        );

        push @result, {
            id          => $id,
            name        => $name,
            disp_points => $a_disp_points,
        };
    }
    $sth->finish();

    return \@result;
}

sub one {
    my (%args) = @_;

    my $dbh = $args{dbh};
    my $id  = $args{id};

    if ( !exists $SUP_CACHE{$id} ) {
        my $sel = q{SELECT name, title, city FROM suppliers WHERE id = ?};
        my $sth = $dbh->prepare($sel);
        $sth->execute($id);
        my ( $name, $title, $city ) = $sth->fetchrow_array();
        $sth->finish();

        # my $section = 'supplier_' . $args{id};
        # my $margin  = $self->app->config->{$section}->{margin};

        $SUP_CACHE{$id} = {
            name  => $name,
            title => $title,
            city  => $city,
        };
    }

    return $SUP_CACHE{$id};
}

sub _dispatch_points {
    my (%args) = @_;

    my $dbh    = $args{dbh};
    my $sup_id = $args{sup_id};
    my @result = ();

    #     my $sel = <<'EOF';
    #         SELECT
    #             id,
    #             ship_id,
    #             depa_area_id,
    #             depa_city_id,
    #             depa_wh_id
    #         FROM sup_dispatch_points
    #         WHERE sup_id = ?
    #         ORDER BY id ASC
    # EOF
    #     my $sth = $dbh->prepare($sel);
    #     $sth->execute($sup_id);

    #     while ( my ( $id, $ship_id, $depa_area_id, $depa_city_id, $depa_wh_id )
    #         = $sth->fetchrow_array() ) {

    #         # my $h_wh = $self->get_wh($depa_wh_id);

    #         push @result, {
    #             sup_id       => $sup_id,
    #             id           => $id,
    #             ship_id      => $ship_id,
    #             depa_area_id => $depa_area_id,
    #             depa_city_id => $depa_city_id,
    #             depa_wh_id   => $depa_wh_id,
    #             # descr        => $h_wh->{number} . ' - ' . $h_wh->{addr_short},
    #         };

    #     }

    # $sth->finish;
    return \@result;
}

#
# TODO: class will depend on shipper id, move method to shipper class
#
# sub get_wh {
# 	my ( $self, $wh_id ) = @_;

# 	my $sel = qq{
# 		SELECT addr_short, descr, number, city_descr, stl_descr
# 		FROM np_warehouse
# 		WHERE id = $wh_id
# 	};
# 	my $sth = $self->app->dbh->prepare($sel);
# 	$sth->execute;
# 	my ( $addr_short, $descr, $number, $city_descr, $stl_descr ) = $sth->fetchrow_array();
# 	$sth->finish;

# 	return {
# 		addr_short => $addr_short,
# 		descr      => $descr,
# 		number     => $number,
# 		city_descr => $city_descr,
# 		stl_descr  => $stl_descr,
# 	};
# }

1;
