use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

exit; # Tests not done yet

my $t = Test::Mojo->new('BlacklistChecker');
my $testname;

$testname='Invalid API Call for undefined routes';
$t->post_ok('/')
    ->status_is(400, $testname)
    ->content_like(qr/Invalid API call/i, $testname);

$testname='Invalid API Call for unsupported method';
$t->get_ok('/api/v1/check')
    ->status_is(400, $testname)
    ->content_like(qr/Invalid API call/i, $testname);

$testname='Start a scan';
$t->post_ok(
    '/api/v1/check' => {
        'Content-type' => 'application/json'
    },
    json => {
        url => 'https://siwecos.de',
        dangerlevel => 10,
        callbackurls => [ 'https://localhost:8080/api/test' ],
        userAgent => 'none',
    }
)
    ->status_is(200, $testname)
    ->content_like(qr/^OK \(\d+\)$/, $testname);

$testname='Invalid parameter callbackurl';
$t->post_ok(
    '/api/v1/check' => {
        'Content-type' => 'application/json'
    },
    json => {
        url => 'https://siwecos.de',
        dangerlevel => 10,
        callbackurls => 'https://localhost:8080/api/test',
        userAgent => 'none',
    }
)
    ->status_is(400, $testname)
    ->content_like(qr/not an array/, $testname);

$testname='Invalid parameter dangerlevel';
$t->post_ok(
    '/api/v1/check' => {
        'Content-type' => 'application/json'
    },
    json => {
        url => 'https://siwecos.de',
        dangerlevel => 11,
        callbackurls => ['https://localhost:8080/api/test'],
        userAgent => 'none',
    }
)
    ->status_is(400, $testname)
    ->json_has('/dangerlevel', $testname);

done_testing();
