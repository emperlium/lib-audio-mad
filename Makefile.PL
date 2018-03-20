use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::MAD',
    VERSION_FROM        => 'lib/Nick/Audio/MAD.pm',
    AUTHOR              => 'Nick Peskett',
    LIBS                => [ '-lmad' ],
    MYEXTLIB            => 'dither.o'
);
