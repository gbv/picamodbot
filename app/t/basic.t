use Test::More;
use v5.14;

use Plack::Test;
use HTTP::Request::Common;

use_ok 'GBV::App::Picamodbot';

my $app = GBV::App::Picamodbot->new;

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET '/');

    is $res->code, 200, 'response code';
};

done_testing;
