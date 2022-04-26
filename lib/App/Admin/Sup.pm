package App::Admin::Sup;

use strict;
use warnings;

use Util::Renderer;
use Util::Supplier;
# with 'App::Role::NovaPoshtaDb';

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $tpl_path = $app->config->{templates}->{path};
    my $dbh      = $app->dbh;
    my $root_dir = $app->root_dir;

    my $a_sups = Util::Supplier::list( dbh => $dbh );
    my $list   = q{};
    foreach my $h ( @{$a_sups} ) {
        # for each supplier show saved senders
        # my $a_senders = $self->np_get_cps(
        #     sup_id    => $h->{id},
        #     is_sender => 1,
        # );
        # my $senders = q{};
        # foreach my $hs ( @{$a_senders} ) {
        #     # for each sender show (contact) persons
        #     my $persons = q{};
        #     foreach my $hp ( @{ $hs->{cp_persons} } ) {
        #         $persons .= $self->parse_html( $tpl_path . '/sup', 'list-item-person.html', $hp );
        #     }
        #     $hs->{persons} = $persons || q{-};

        #     $senders .= $self->parse_html( $tpl_path . '/sup', 'list-item-sender.html', $hs );
        # }
        # $h->{np_senders} = $senders || q{-};

        # for each supplier show (filter by shipper?) saved dispatch places
        # $h->{np_disp_points} = $self->_build_disp_points(
        #     disp_points => $h->{disp_points},
        # );

        # $h->{np_areas_upd}        = $self->_get_upd_dt('np_area');
        # $h->{np_cities_upd}       = $self->_get_upd_dt('np_city');
        # $h->{np_whs_upd}          = $self->_get_upd_dt('np_warehouse');
        # $h->{np_cargotypes_upd}   = $self->_get_upd_dt('np_cargo_types');
        # $h->{np_cargodescr_upd}   = $self->_get_upd_dt('np_cargo_descr');
        # $h->{np_payertypes_upd}   = $self->_get_upd_dt('np_payer_types');
        # $h->{np_paymentforms_upd} = $self->_get_upd_dt('np_payment_forms');
        # $h->{np_servicetypes_upd} = $self->_get_upd_dt('np_service_types');

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/sup',
            tpl_name => 'list-item.html',
            h_vars   => {
                id   => $h->{id},
                name => $h->{name},
            },
        );
    }

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/sup',
        tpl_name => 'list.html',
        h_vars   => {
            list => $list,
        },
    );

    my $page = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        tpl_name => 'layout.html',
        h_vars   => {
            body_html => $body,
        },
    );

    return {
        body => $page,
    };
}

# sub _get_upd_dt {
#     my ( $self, $table ) = @_;

#     my $q1   = qq{SELECT MAX(upd_dt) FROM $table};
#     my $sth1 = $app->dbh->prepare($q1);
#     $sth1->execute;
#     my ($upd_dt) = $sth1->fetchrow_array();
#     $sth1->finish;

#     return $upd_dt;
# }

# sub _build_disp_points {
#     my ( $self, %args ) = @_;

#     my $tpl_path      = $app->config->{templates}->{path};
#     my $a_disp_points = $args{disp_points};
#     my $result        = q{};

#     my $a_areas = $self->np_get_areas();

#     foreach my $hdp ( @{$a_disp_points} ) {
#         $hdp->{area_options} = $self->get_options(
#             items    => $a_areas,
#             id_sel   => $hdp->{depa_area_id},
#             tpl_path => $tpl_path . '/sup',
#             tpl_file => 'area-option.html',
#         );

#         if ( $hdp->{depa_area_id} ) {
#             my $a_cities = $self->np_get_cities(
#                 area_id => $hdp->{depa_area_id},
#             );
#             $hdp->{city_options} = $self->get_options(
#                 items    => $a_cities,
#                 id_sel   => $hdp->{depa_city_id},
#                 tpl_path => $tpl_path . '/sup',
#                 tpl_file => 'city-option.html',
#             );
#         }

#         if ( $hdp->{depa_area_id} && $hdp->{depa_city_id} ) {
#             my $a_whs = $self->np_get_warehouses(
#                 city_id => $hdp->{depa_city_id},
#             );
#             $hdp->{wh_options} = $self->get_options(
#                 items    => $a_whs,
#                 id_sel   => $hdp->{depa_wh_id},
#                 tpl_path => $tpl_path . '/sup',
#                 tpl_file => 'wh-option.html',
#             );
#         }

#         $result .= $self->parse_html( $tpl_path . '/sup', 'list-item-dispoint.html', $hdp );
#     }

#     return $result || q{-};
# }

# __PACKAGE__->meta->make_immutable();

1;
