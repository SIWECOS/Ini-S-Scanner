package BlacklistChecker::Command::list;
use Mojo::Base 'Mojolicious::Commands';

has description => 'Handle blacklists';
has hint        => <<EOF;

See 'APPLICATION list help COMMAND' for more information on a specific
command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['BlacklistChecker::Command::list'] };

sub help { shift->run(@_) }

1;

=encoding utf8

=head1 NAME

BlacklistChecker::Command::list - List command

=head1 SYNOPSIS

  Usage: APPLICATION list COMMAND [OPTIONS]

=head1 DESCRIPTION

L<BlacklistChecker::Command::list> lists available L<List> commands.

=head1 ATTRIBUTES

L<BlacklistChecker::Command::list> inherits all attributes from
L<Mojolicious::Commands> and implements the following new ones.

=head2 description

  my $description = $minion->description;
  $minion         = $minion->description('Foo');

Short description of this command, used for the command list.

=head2 hint

  my $hint = $minion->hint;
  $minion  = $minion->hint('Foo');

Short hint shown after listing available L<List> commands.

=head2 message

  my $msg = $minion->message;
  $minion = $minion->message('Bar');

Short usage message shown before listing available L<List> commands.

=head2 namespaces

  my $namespaces = $minion->namespaces;
  $minion        = $minion->namespaces(['MyApp::Command::List']);

Namespaces to search for available L<Minion> commands, defaults to
L<BlacklistChecker::Command::list>.

=head1 METHODS

L<BlacklistChecker::Command::list> inherits all methods from L<Mojolicious::Commands>
and implements the following new ones.

=head2 help

  $minion->help('app');

Print usage information for L<List> command.

=head1 SEE ALSO

L<List>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
