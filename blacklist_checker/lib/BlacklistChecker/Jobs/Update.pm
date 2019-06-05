package BlacklistChecker::Jobs::Update;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::Date;

sub register {
    my ($self, $app) = @_;
    $app->minion->add_task(update => \&_update);
}

sub _update {
    my ($job) = @_;
    my $start= time;
    my $interval= $ENV{UPDATE_INTERVAL} || 6*60*60;
    $job->note(
        status   => 'updating',
        duration => '-',
        updated  => '-',
        time     => Mojo::Date->new( $start )->to_datetime,
        next     => '-',
    );
    my $updated= $job->app->blacklists->update;
    my $end= time;
    $job->note(
        status   => 'updated',
        duration => $end - $start,
        updated  => $updated,
        time     => Mojo::Date->new( $end )->to_datetime,
        next     => Mojo::Date->new( time + $interval )->to_datetime,
    );
    $job->retry( { delay => $interval } );
}

1;

