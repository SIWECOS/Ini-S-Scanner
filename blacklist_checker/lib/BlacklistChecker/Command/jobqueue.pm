package BlacklistChecker::Command::jobqueue;
use Mojo::Base 'Mojolicious::Commands';

has description => 'Handle jobqueues';
has hint        => <<EOF;

See 'APPLICATION jobqueue help COMMAND' for more information on a specific
command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['BlacklistChecker::Command::jobqueue'] };

sub help { shift->run(@_) }

1;

=encoding utf8

=head1 NAME

BlacklistChecker::Command::jobqueue - jobqueue command

=head1 SYNOPSIS

  Usage: APPLICATION jobqueue COMMAND [OPTIONS]

=head1 DESCRIPTION

L<BlacklistChecker::Command::list> lists available L<Jobqueue> commands.

=head1 ATTRIBUTES

L<BlacklistChecker::Command::jobqueue> inherits all attributes from
L<Mojolicious::Commands> and implements the following new ones.

=head2 description

  my $description = $minion->description;
  $minion         = $minion->description('Foo');

Short description of this command, used for the command list.

=head2 hint

  my $hint = $minion->hint;
  $minion  = $minion->hint('Foo');

Short hint shown after listing available L<Jobqueue> commands.

=head2 message

  my $msg = $minion->message;
  $minion = $minion->message('Bar');

Short usage message shown before listing available L<Jobqueue> commands.

=head2 namespaces

  my $namespaces = $minion->namespaces;
  $minion        = $minion->namespaces(['MyApp::Command::List']);

Namespaces to search for available L<Minion> commands, defaults to
L<BlacklistChecker::Command::jobqueue>.

=head1 METHODS

L<BlacklistChecker::Command::jobqueue> inherits all methods from L<Mojolicious::Commands>
and implements the following new ones.

=head2 help

  $minion->help('app');

Print usage information for L<jobqueue> command.

=head1 SEE ALSO

L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
