# lib-audio-mad

Interface to the libmad library.

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

    while ( $mp3 -> read_frame() ) {
        $buff_in .= $MP3_FRAME;
        $mad -> decode()
            and printf "decoded %d bytes\n", length( $buff_out );
    }
    $mad -> decode( 1 )
        and printf "decoded %d final bytes\n", length( $buff_out );
