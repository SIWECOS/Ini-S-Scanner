package BlacklistChecker::Command::list::schedule;
use Mojo::Base 'Mojolicious::Command';

has description => 'Schedule blacklists update';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;
    my $updatetasks= $self->app->minion->backend->list_jobs(
        0, 1, { tasks => [qw[update]]}
    );
    if ( $updatetasks->{total} > 0 ) {
        print "There already is update job #",$updatetasks->{jobs}[0]{id},"\n";
        exit;
    }
    my $id= $self->app->minion->enqueue( 'update' );
    print "Update job #$id scheduled\n";
}

1;

=encoding utf8

=head1 NAME

BlacklistChecker::Command::list::schedule

=head1 SYNOPSIS

  Usage: APPLICATION list schedule

=head1 DESCRIPTION

L<BlacklistChecker::Command::list::schedule> will schedule regulare updates
of the blacklists

