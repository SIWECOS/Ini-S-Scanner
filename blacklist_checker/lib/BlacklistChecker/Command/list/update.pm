package BlacklistChecker::Command::list::update;
use Mojo::Base 'Mojolicious::Command';

has description => 'Update blacklists';
has usage       => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;
  my $updateinfo= $self->app->blacklists->update;
  print "Lists updated: ",$updateinfo->{updates},"\n";
  print "Lists kept   : ",$updateinfo->{kept},"\n";
  print "Lists failed : ",$updateinfo->{fails},"\n";
  my @dropped= sort @{$updateinfo->{dropped}};
  if (scalar @dropped) {
    print "Lists dropped:\n";
    foreach (@dropped) {
      print "  $_\n";
    }
  }
}

1;

=encoding utf8

=head1 NAME

BlacklistChecker::Command::list::update

=head1 SYNOPSIS

  Usage: APPLICATION list update

=head1 DESCRIPTION

L<BlacklistChecker::Command::list::update> will download the
newest version of all blacklists.

