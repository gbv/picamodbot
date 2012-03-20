#!/usr/bin/env perl

use Dancer;

#use lib path(dirname(__FILE__), 'lib');
use File::Spec::Functions qw(catdir catfile rel2abs);
use File::Basename qw(dirname);
use lib rel2abs(catdir(dirname($0),'lib'));

use GBV::App::picamodbot;

dance;
