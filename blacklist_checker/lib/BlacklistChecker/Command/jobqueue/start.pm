package BlacklistChecker::Command::jobqueue::start;
use Mojo::Base 'Mojolicious::Command';
use Minion::Command::minion::worker;

has description => 'Start the jobqueue worker';
has usage       => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;
  # initialize blacklists
  $self->app->blacklists;
  my $worker= $self->app->minion->worker;
  my $log = $self->app->log;
  $log->info("Worker $$ started");
  $worker->on(dequeue => sub { pop->once(spawn => \&Minion::Command::minion::worker::_spawn) });
  $worker->run;
  $log->info("Worker $$ stopped");
}

1;

=encoding utf8

=head1 NAME

BlacklistChecker::Command::jobqueue::start

=head1 SYNOPSIS

  Usage: APPLICATION jobqueue start

=head1 DESCRIPTION

L<BlacklistChecker::Command::jobqueue::start> will start a new minion (jobqueue) worker.

# b load /app/blacklist_checker/lib/BlacklistChecker/Command/jobqueue/start.pm