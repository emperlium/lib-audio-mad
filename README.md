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

## Methods

### new()

Instantiates a new Nick::Audio::MAD object.

All arguments are optional.

- buffer\_in

    Scalar that'll be used to pull MP3 frames from.

- buffer\_out

    Scalar that'll be used to push decoded PCM to.

- channels

    How many audio channels the stream has.

- gain

    Decibels of gain to apply to the decoded PCM.

- debug

    Whether verbose decoding info will be written to STDERR.

### set\_buffer\_in\_ref()

Sets the scalar that'll be used to pull MP3 frames from.

### set\_buffer\_out\_ref()

Sets the scalar that'll be used to push decoded PCM to.

### decode()

Decodes the frame (if present) in the buffer\_in scalar, returning number of bytes of PCM written to buffer\_out.

If the argument is 1, any buffers will be flushed.

    $buff_in .= $MP3_FRAME;
    $read = $mad -> decode()
        or next;
    printf "decoded %d bytes\n", $read;
    # do something with buffer_out
