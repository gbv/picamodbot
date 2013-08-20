use v5.14;
use Plack::Builder;
use GBV::App::Picamodbot;

use File::Spec::Functions qw(catdir rel2abs);
use File::Basename qw(dirname);

my $app = GBV::App::Picamodbot->new(
    root   => rel2abs(catdir(dirname($0),'root')),
);

my $debug = ($ENV{PLACK_ENV} // '') eq 'debug';

builder {
    enable_if { $debug } 'Debug';
    enable_if { $debug } 'Debug::TemplateToolkit';

    enable 'SimpleLogger';
    enable_if { $debug }  'Log::Contextual', level => 'trace';
    enable_if { !$debug } 'Log::Contextual', level => 'warn';

    $app->to_app;
};
