use Test::More;
use v5.14;

ok(1);

done_testing;

__END__
use GBV::App::picamodbot;
use Dancer::Test;

route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 200, 'response status is 200 for /';

done_testing;
