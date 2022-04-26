package App::Admin::Cat::Delete;

use strict;
use warnings;

use Util::Tree;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $o_params = $o_request->parameters();
    my $id       = $o_params->{id} || 0;

    if ( $id == 1 ) {
        return {
            url => $app->config->{site}->{host} . '/admin/cat',
        };
    }

    my @to_delete = _get_cat_childs( $app->dbh, $id );
    push @to_delete, $id;
    my $to_delete = join q{,}, @to_delete;

    my $del = qq{DELETE FROM pages WHERE id IN ($to_delete)};
    $app->dbh->do($del);

    Util::Tree::update_child_qty( dbh => $app->dbh );

    return {
        url => $app->config->{site}->{host} . '/admin/cat',
    };
}

sub _get_cat_childs {
    my ( $dbh, $parent_id ) = @_;

    my @result = ();

    my $sel = q{SELECT id FROM pages WHERE parent_id=?};
    my $sth = $dbh->prepare($sel);
    $sth->execute($parent_id);
    while ( my ($id) = $sth->fetchrow_array() ) {
        push @result, $id;
        push @result, _get_cat_childs( $dbh, $id );
    }
    $sth->finish();

    return @result;
}

1;
