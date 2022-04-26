package App::Admin::Jq;

use strict;
use warnings;

use POSIX ();
use POSIX qw(strftime);

use Util::Renderer;
# use Util::JobQueue;
use Util::DB;

our $VERSION = '1.1';

sub doit {
    my ( undef, %args ) = @_;

    my $app       = $args{app};
    my $o_request = $args{o_request};

    my $tpl_path = $app->config->{templates}->{path};
    my $root_dir = $app->root_dir;
    my $dbh      = $app->dbh;

    # # job queue DB connection
    # my $dbh = Util::DB::get_dbh(
    #     db_name => Util::JobQueue::db_name(),
    #     db_user => $app->config->{mysql}->{user},
    #     db_pass => $app->config->{mysql}->{pass},
    # );
    # $dbh->do( q{USE } . Util::JobQueue::db_name() );

    my $queue_list = queue_list(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        dbh      => $dbh,
    );

    my $error_list = error_list(
        root_dir => $root_dir,
        tpl_path => $tpl_path,
        dbh      => $dbh,
    );

    my $body = Util::Renderer::parse_html(
        root_dir => $root_dir,
        tpl_path => $tpl_path . '/jq',
        tpl_name => 'list.html',
        h_vars   => {
            queue_list => $queue_list,
            error_list => $error_list,
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

sub queue_list {
    my (%args) = @_;

    my $dbh      = $args{dbh};
    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};

    my $list      = q{};
    my $max_age   = 0;
    my $max_count = 0;
    my $h_funcmap = $dbh->selectall_hashref( 'SELECT funcid, funcname FROM funcmap', 'funcid' );

    foreach my $funcid (
        sort { $h_funcmap->{$a}{funcname} cmp $h_funcmap->{$b}{funcname} }
        keys %{$h_funcmap}
    ) {
        my $funcname = $h_funcmap->{$funcid}{funcname};
        # next if $job && $funcname ne $job;

        my $now   = time;
        my $h_inf = $dbh->selectrow_hashref(
            "SELECT COUNT(*) AS 'count', MIN(run_after) AS 'oldest' FROM job WHERE funcid = ? AND run_after <= $now",
            undef, $funcid
        );
        my $behind = $h_inf->{count} ? ( $now - $h_inf->{oldest} ) : 0;

        # okay by default, then we apply rules:
        my $okay = 1;
        if ( $behind > $max_age ) {
            $okay = 0;
        }
        if ( $h_inf->{count} > $max_count ) {
            $okay = 0;
        }
        next if $okay;
        # $some_alert = 1;

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/jq',
            tpl_name => 'funcs-item.html',
            h_vars   => {
                funcname => $funcname,
                count    => $h_inf->{count},
                behind   => $behind,
            },
        );
    }

    return $list;
}

sub error_list {
    my (%args) = @_;

    my $dbh      = $args{dbh};
    my $root_dir = $args{root_dir};
    my $tpl_path = $args{tpl_path};

    my $list = q{};

    my $sql = 'SELECT error_time, jobid, message FROM error ORDER BY error_time ASC LIMIT 10';
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    while ( my ( $error_time, $jobid, $message ) = $sth->fetchrow_array() ) {
        my $time_str = strftime( '%Y-%m-%d %H:%M:%S', localtime $error_time );

        $list .= Util::Renderer::parse_html(
            root_dir => $root_dir,
            tpl_path => $tpl_path . '/jq',
            tpl_name => 'errors-item.html',
            h_vars   => {
                jobid      => $jobid,
                message    => $message,
                error_time => $time_str,
            },
        );
    }
    $sth->finish;

    return $list;
}

1;
