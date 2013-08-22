use Test::More;
use v5.14;

use Plack::Test;
use HTTP::Request::Common;

use_ok 'GBV::App::Picamodbot';

my $app = GBV::App::Picamodbot->new(
    root => 'root'
);

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET '/');

    is $res->code, 200, 'response code at /';

    my $res = $cb->(GET '/edit.json');
    is $res->code, 200, 'response code at /edit.json';
    is $res->header('Content-Type'), 'application/json', 'application/json at /edit.json';
};

done_testing;
