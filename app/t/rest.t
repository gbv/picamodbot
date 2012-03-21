use strict;
use warnings;
use Test::More;

use GBV::App::picamodbot;
use Dancer qw(:syntax !pass);
use Dancer::Test;
use Test::JSON::Entails;

set plugins => { 
    Database => { 
        dsn => 'dbi:SQLite:dbname=:memory:', 
    } 
};

# create edit
my $r = dancer_response POST => '/edit', { 
    params => {
        record  => 'test:ppn:12345 ',
        deltags => '012A,',
    } 
};
is $r->status, 202, 'edit created';

my $edit = {
    record => 'test:ppn:12345',
    deltags => '012A',
    edit => 1
};

entails $r->content, $edit, 'edit created';

# get edit
$r = dancer_response GET => '/edit/1.json';
is $r->status, 200, 'got edit';
entails $r->content, $edit, 'got edit content';

# list edits
$r = dancer_response GET => '/edit.json';
is $r->status, 200, 'list edits';
entails $r->content, { changes => [ $edit ] }, 'edits.json';

# delete edit
# TODO...

# edit gone
# TODO...

done_testing;

