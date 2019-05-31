package BlacklistChecker;
use Mojo::Base 'Mojolicious';
use Carp;
use Blacklists;

$ENV{SCANNER_NAME}= 'BLACKLISTS';
$ENV{VERSION}= "3.0.0";

has blacklists => sub {
    my ($self)= @_;
    if (not defined $self->{bl}) {
        $self->app->log->debug("Initializing blacklists");
        my $config= $self->{config};
        $self->{bl}= Blacklists->new( $config->{blacklists} );
        $self->app->log->debug("done initializing blacklists");
    }
    return $self->{bl};
};

# This method will run once at server start
sub startup {
    my $self = shift;

    # Load configuration from hash returned by config file
    my $config = $self->plugin('Config');

    $self->log->handle(\*STDOUT);

    # Configure the application
    # $self->secrets($config->{secrets});

    croak "Config error: Missing blacklists" unless 'HASH' eq ref $config->{blacklists};
    $self->blacklists; # initialize blacklists

    $self->plugin(Minion => {SQLite => 'jobs.sqlite'});
    ## $self->plugin('Minion::Admin');
    $self->plugin('BlacklistChecker::Jobs::CheckDomain');

    # Router
    my $r = $self->routes;

    # API calls
    $r->post('/api/v1/check')->to('api#check');
    $r->get('/check/#domain')->to('api#direct_check');

    ## # Secure access to the admin ui with Basic authentication
    ## my $under = $self->routes->under('/minion' =>sub {
    ##   my $c = shift;
    ##   return 1 if $c->req->url->to_abs->userinfo eq 'Bender:rocks';
    ##   $c->res->headers->www_authenticate('Basic');
    ##   $c->render(text => 'Authentication required!', status => 401);
    ##   return undef;
    ## });
    ## $self->plugin('Minion::Admin' => {route => $under});

    # Default -> API Error
    $r->any('/')->to('api#error')->partial(1);

    # Add another namespace to load commands from
    push @{$self->commands->namespaces}, 'BlacklistChecker::Command';

}

1;

# b load /home/blacklist_checker/script/../lib/BlacklistChecker.pm
