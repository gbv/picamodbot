package GBV::App::Picamodbot::Queue;

use v5.14;
use Moo;
use utf8;

sub list {
    return [ { testutf8 => 'ÄÖÜ' } ];
}

1;
