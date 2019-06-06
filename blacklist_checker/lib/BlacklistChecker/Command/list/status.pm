package BlacklistChecker::Command::list::status;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Date;

has description => 'Update blacklists';
has usage       => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;
  my $updatetasks= $self->app->minion->backend->list_jobs(
    0, 1, { tasks => [qw[update]]}
  );
  if ( $updatetasks->{total} < 1 ) {
    print "There is no update job. Try to schedule one.\n";
    exit 1;
  }
  my $notes= $updatetasks->{jobs}[0]{notes};
  print "Last update  : ",$notes->{time},"\n";
  print "Next update  : ",$notes->{next},"\n";
  print "Duration     : ",$notes->{duration}," sec\n";
  if ($notes->{status} eq "running") {
      print "\nUpdate is in progress.\n";
      exit;
  }
  my $updateinfo= $notes->{updated};
  my $width= (sort {$b<=>$a} map length, map @$_, values %$updateinfo)[0];
  my $blacklists= $self->app->blacklists->get_lists;
  foreach my $status (qw(dropped failed kept updated )) {
    next unless @{$updateinfo->{$status}};
    printf "Lists %-7s: %d\n", $status, scalar @{$updateinfo->{$status}};
    foreach (sort @{$updateinfo->{$status}}) {
        printf "      %-${width}s (%s)\n", $_, Mojo::Date->new($blacklists->{$_}{updated})->to_datetime;
    }
  }
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