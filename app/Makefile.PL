use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'picamodbot',
    AUTHOR              => q{Jakob Voss <voss@gbv.de>},
    VERSION_FROM        => 'lib/GBV/App/picamodbot.pm',
    ABSTRACT            => 'PICA+ modification bot',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'    => 0,
        'YAML'          => 0,
        'Dancer'        => 1.3091,
        'Dancer::Plugin::Database' => 1.80,
        'PICA::Record'  => 0,
        'Test::JSON::Entails' => 0.1,
        # ...
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'GBV-App-picamodbot-*' },
);