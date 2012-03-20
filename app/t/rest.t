use strict;
use warnings;
use Test::More;

use GBV::App::picamodbot;
use Dancer ':syntax';
use Dancer::Test;
use Test::JSON::Entails;

set plugins => { 
    Database => { 
        dsn => 'dbi:SQLite:dbname=:memory:', 
    } 
};

# create an edit
my $resp = dancer_response POST => '/edit', { 
    params => {
        record  => 'test:ppn:12345 ',
        deltags => '012A,',
    } 
};
is $resp->status, 202, 'edit created';

my $edit = {
    record => 'test:ppn:12345',
    deltags => '012A',
    edit => 1
};

entails $resp->content, $edit, 'edit response';

# get edit
$resp = dancer_response GET => '/edit/1';
is $resp->status, 200, 'got edit';

entails $resp->content, $edit, 'got edit content';

# list edits
# TODO...

# delete edit
# TODO...

# edit gone
# TODO...

done_testing;

