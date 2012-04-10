#!/usr/bin/env perl
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
        'Template'      => 0,
        'Net::IP::AddrRanges' => 0,
        'Try::Tiny'     => 0,
        'LWP::Simple'   => 0,
        'Test::More'    => 0,
        'YAML'          => 0,
        'Dancer'        => 1.3091,
        'Plack::Runner' => 0,
        'Dancer::Plugin::Database' => 1.80,
        'Dancer::Plugin::REST'     => 0,
        'Dancer::Plugin::Feed'     => 0,
        'DateTime::Format::RFC3339' => 0,
        'POSIX'     => 0,

        'PICA::Record'             => 0.583,
        'Test::JSON::Entails'      => 0.1,
        # ...
        'Crypt::OpenSSL::Random'   => 0.04,
        'Text::Diff'    => 1.37,

        'Plack::Handler::Starman'  => 0, # required to deploy with starman
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'GBV-App-picamodbot-*' },
);
