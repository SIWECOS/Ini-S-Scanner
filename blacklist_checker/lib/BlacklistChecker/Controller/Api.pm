package BlacklistChecker::Controller::Api;
use Mojo::Base 'Mojolicious::Controller';

# Add a urls-validation
sub _urls {
    my ($v, $name, @args) = @_;
    foreach my $value (@args) {
        my $url = Mojo::URL->new($value);
        if ($url->scheme ne 'https' and $url->scheme ne 'http' ) {
            return "$value is not an accepted url";
        }
    }
    return undef;
}

sub new {
    my $class= shift;
    my $self= $class->SUPER::new(@_);
    $self->app->validator->add_check( urls => \&_urls );
    return $self;
}

sub check {
    my $self = shift;

    # get the data
    my $hash = $self->req->json;
    if (not defined $hash) {
        return $self->render(
            json => { error => "No valid JSON found" }, 
            status => 405);
    }

    # Validate the data
    my $v = $self->validation;
    $v->input($hash);

    # url
    $v->required('url')->urls();

    # dangerlevel
    $v->optional('dangerlevel')->num(1, 10); # ignored
    
    # callbackurls
    if ($hash->{callbackurls} and ref $hash->{callbackurls} ne 'ARRAY') {
        $v->error(callbackurls => ['not an array']);
    } else {
        $v->optional('callbackurls')->urls();
    }
    
    # userAgent
    $v->optional('userAgent'); # ignored
    
    # validation done
    if ($v->has_error) {
        # and failed
        return $self->render(json => $v->{error}, status => 400);
    }

    # enqueue the check
    my $id = $self->minion->enqueue(
        check_domain => [$v->param('url'), $v->every_param('callbackurls')]
    );

    # and report success
    return $self->render(data => 'OK ('.$id.')');
};

sub direct_check {
    my $self= shift;
    my $domain= $self->param('domain');
    my $bl= $self->app->blacklists;
    my $result= $bl->domain_check( $domain );
    return $self->render(data => $result->to_String(), format=> 'json', status => 200);
}

sub error {
    my $self = shift;
    return $self->render(json => {error => 'Invalid API call'}, status => 400);
};

1;

# b load /home/blacklist_checker/script/../lib/BlacklistChecker/Controller/Api.pm
