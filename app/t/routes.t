use strict;
use warnings;
use Test::More;

use GBV::App::picamodbot;
use Dancer::Test;

route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 200, 'response status is 200 for /';

done_testing;
