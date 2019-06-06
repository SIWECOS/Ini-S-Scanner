package BlacklistChecker::Command::list::update;
use Mojo::Base 'Mojolicious::Command';

has description => 'Update blacklists';
has usage       => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;
  my $updateinfo= $self->app->blacklists->update;
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

BlacklistChecker::Command::list::update

=head1 SYNOPSIS

  Usage: APPLICATION list update

=head1 DESCRIPTION

L<BlacklistChecker::Command::list::update> will download the
newest version of all blacklists.

