package BlacklistChecker::Jobs::CheckDomain;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;

sub register {
    my ($self, $app) = @_;
    $app->minion->add_task(check_domain => \&_check_domain);
}

sub _check_domain {
    my ($job, $url, $callbacks) = @_;
    my $count= 0;
    my $success= 0;
    for ($url) {
        s<^https?://><>;
        s<[:/].*$><>;
        my $result= $job->app->blacklists->domain_check( $_ );
        my $ua  = $job->app->ua;
        $ua->max_redirects(3);
        my $result_string= $result->to_String();
        $job->app->log->error($result_string);
        foreach my $cb (@$callbacks) {
            my $res = _checked_result( $job, $ua->post( $cb, { 'Content-Type' => 'application/json;charset=UTF-8' }, $result_string ) );
            ++$count;
            ++$success if $res;
        }
    }
    $job->finish( "$success/$count successful callbacks" );
}


sub _checked_result {
    my($job, $http)= @_;
    my $res= $http->result;
    if (not $res->is_success) {
        if ($res->is_error)    {
            $job->app->log->error("Could not callback to ".$http->req->url.": ".$res->message);
            return undef;
        }
        if ($res->code == 301) {
            $job->app->log->error("Too many redirects for ".$http->req->url.": ".$res->headers->location);
            return undef;
        }
        $job->app->log->error("Failed to callback to ".$http->req->url." for unknown reason");
        return undef;
    }
    return $res;
}

1;

