# lib-audio-mad

Interface to the libmad (MP3 decoding) library.

## Dependencies

You'll need the [libmad library](https://www.underbit.com/products/mad/).

On Ubuntu distributions;

    sudo apt install libmad0-dev

## Installation

    perl Makefile.PL
    make test
    sudo make install

## Example

    use Nick::Audio::MAD;
    use Nick::MP3::File '$MP3_FRAME';

    my $mp3 = Nick::MP3::File -> new( 'test.mp3' );

    my( $buff_in, $buff_out );
    my $mad = Nick::Audio::MAD -> new(
        'buffer_in'     => \$buff_in,
        'buffer_out'    => \$buff_out,
        'channels'      => $mp3 -> is_stereo() ? 2 : 1,
        'gain'          => -3,
        'debug'         => 1
    );

    use FileHandle;
    my $sox = FileHandle -> new( sprintf
            "| sox -q -t raw -b 16 -e s -r %d -c %d - -t pulseaudio",
            $mp3 -> get_samplerate(),
            $mp3 -> is_stereo() ? 2 : 1
    ) or die $!;
    binmode $sox;

    while ( $mp3 -> read_frame() ) {
        $buff_in .= $MP3_FRAME;
        $mad -> decode()
            and $sox -> print( $buff_out );
    }
    $mad -> decode( 1 )
        and $sox -> print( $buff_out );
    $sox -> close();
