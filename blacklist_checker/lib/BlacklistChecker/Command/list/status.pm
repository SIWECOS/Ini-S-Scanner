package BlacklistChecker::Command::list::status;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Date;

has description => 'Show blacklist update status';
has usage       => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;
  my $updatetasks= $self->app->minion->backend->list_jobs(
    0, 1, { tasks => [qw[update]]}
  );
  my $notes;
  if ( $updatetasks->{total} < 1 ) {
    print "There is no update job. Try to schedule one.\n";
  } else {
    $notes= $updatetasks->{jobs}[0]{notes};
    print "Last update  : ",$notes->{time},"\n";
    print "Next update  : ",$notes->{next},"\n";
    print "Duration     : ",$notes->{duration}," sec\n";
    print "Currently    : ",$notes->{status},"\n";
    if ($notes->{status} eq "running") {
        print "\nUpdate is in progress.\n";
        exit;
    }
    if ($updatetasks->{jobs}[0]{state} eq 'failed') {
      print "Status       : ",$updatetasks->{jobs}[0]{state},"\n";
      print "               ",$updatetasks->{jobs}[0]{result},"\n";
    }
  }
  my $status= $self->app->blacklists->status_string;
  print $status;
  exit 1 unless $status;
}

1;

=encoding utf8

=head1 NAME

BlacklistChecker::Command::list::status

=head1 SYNOPSIS

  Usage: APPLICATION list status

=head1 DESCRIPTION

L<BlacklistChecker::Command::list::status> will show the current
status of the list update.

# b load /app/blacklist_checker/lib/BlacklistChecker/Command/list/status.pm