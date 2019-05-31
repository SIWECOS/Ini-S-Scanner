package BlacklistChecker::Command::list::show;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Date;

has description => 'Show blacklists';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;
    my %blacklists;
    my $lists= $self->app->blacklists->get_lists;
    foreach (sort keys %$lists) {
      print "$_:\n";
      if ($lists->{$_}{updated}) {
        print "  Reference: ",$lists->{$_}{reference},"\n";
        print "  Kind     : ",$lists->{$_}{kind},"\n";
        print "  Updated  : ",Mojo::Date->new($lists->{$_}{updated})->to_datetime(),"\n";
        print "  Entries  : ",scalar keys %{$lists->{$_}{domains}},"\n";
      } else {
        print "  no data\n"
      }
      print "\n";
    }
}

1;
#b load /home/blacklist_checker/script/../lib/BlacklistChecker/Command/list/show.pm

=encoding utf8

=head1 NAME

Blacklist::Checker::list::show

=head1 SYNOPSIS

  Usage: APPLICATION show I<TARGET>

=head1 DESCRIPTION

L<BlacklistChecker::Command::list::show> will display information
about all blacklists currently available.
