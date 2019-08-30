package BlacklistChecker;
use Mojo::Base 'Mojolicious';
use Carp;
use Blacklists;

$ENV{SCANNER_NAME}= 'INI_S'; # "INI_S" instead of "BLACKLISTS" to stay compatible to the previous version
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
    my $config = $self->plugin( Config => { file => $self->home . '/etc/blacklist_checker.conf' } );

    $self->log->handle(\*STDOUT);

     # initialize blacklists
    croak "Config error: Missing blacklists"
        unless 'HASH' eq ref $config->{blacklists};

    # Initialize Minion
    croak "Config error: No storage defined for Minion" 
        unless 'HASH' eq ref $config->{minion}
        and defined $config->{minion}->{storage};
    $self->plugin(Minion => {SQLite => $config->{minion}->{storage}});

    if ( $config->{blacklists}->{interval} and $config->{blacklists}->{interval}=~ /^([1-9]\d*)$/ ) {
        $ENV{UPDATE_INTERVAL}= $1;
    }

    # Prepare the minion jobs
    $self->plugin('BlacklistChecker::Jobs::CheckDomain');
    $self->plugin('BlacklistChecker::Jobs::Update');

    # Router
    my $r = $self->routes;

    # API calls
    $r->post('/api/v1/check')->to('api#check');
    $r->get('/check/#domain')->to('api#direct_check');

    ## # The part below can be used to observe the minions
    ## # Secure access to the admin ui with Basic authentication
    ## $self->plugin('Minion::Admin');
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

# b load /app/blacklist_checker/lib/BlacklistChecker.pm
