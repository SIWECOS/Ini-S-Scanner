package BlacklistChecker::Command::list::update;
use Mojo::Base 'Mojolicious::Command';

has description => 'Update blacklists';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;
    $self->app->blacklists->update;
}

1;

# b load /home/blacklist_checker/script/../lib/BlacklistChecker/Command/list/fetch.pm

=encoding utf8

=head1 NAME

Blacklist::Checker::list::fetch

=head1 SYNOPSIS

  Usage: APPLICATION list update I<LIST_ID>

=head1 DESCRIPTION

L<BlacklistChecker::Command::list::fetch> will download the
newest version of our defined blacklists.

=head1 LIST_ID

You can specify which blacklist to fetch by giving the I<LIST_ID>

Use B<ALL> to download all defined blacklists.
