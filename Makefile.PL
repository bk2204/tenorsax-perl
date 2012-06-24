use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'TenorSAX',
    AUTHOR              => q{brian m. carlson <sandals@crustytoothpaste.net>},
    VERSION_FROM        => 'lib/TenorSAX.pm',
    ABSTRACT_FROM       => 'lib/TenorSAX.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'TenorSAX-*' },
);
