use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'kossy_test',
    VERSION_FROM  => 'lib/kossy_test.pm',
    PREREQ_PM     => {
        'Kossy' =>  '0.19',
    },
    MIN_PERL_VERSION => '5.008001'
);

