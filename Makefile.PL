use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::MAD',
    VERSION_FROM        => 'lib/Nick/Audio/MAD.pm',
    PREREQ_PM           => {},
    ABSTRACT            => '',
    AUTHOR              => 'Nick',
    LIBS                => [ '-lmad' ],
    MYEXTLIB            => 'dither.o'
);
