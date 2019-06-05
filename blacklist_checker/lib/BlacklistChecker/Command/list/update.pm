package BlacklistChecker::Command::list::update;
use Mojo::Base 'Mojolicious::Command';

has description => 'Update blacklists';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;
    $self->app->blacklists->update;
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

