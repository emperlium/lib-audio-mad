package Nick::Audio::MAD;

use strict;
use warnings;

use XSLoader;
use Carp;

# sudo apt install libmad0-dev

our $VERSION;

BEGIN {
    $VERSION = '0.01';
    XSLoader::load 'Nick::Audio::MAD' => $VERSION;
}

=pod

=head1 NAME

Nick::Audio::MAD - Interface to the libmad library.

=head1 SYNOPSIS

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

=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::MAD object.

All arguments are optional.

=over 2

=item buffer_in

Scalar that'll be used to pull MP3 frames from.

=item buffer_out

Scalar that'll be used to push decoded PCM to.

=item channels

How many audio channels the stream has.

=item gain

Decibels of gain to apply to the decoded PCM.

=item debug

Whether verbose decoding info will be written to STDERR.

=back

=head2 decode()

Decodes the frame (if present) in the buffer_in scalar, returning number of bytes of PCM written to buffer_out.

If the argument is 1, any buffers will be flushed.

    $buff_in .= $MP3_FRAME;
    $read = $mad -> decode()
        or next;
    printf "decoded %d bytes\n", $read;
    # do something with buffer_out

=cut

sub new {
    my( $class, %settings ) = @_;
    for ( qw( in out ) ) {
        exists( $settings{ 'buffer_' . $_ } )
            or $settings{ 'buffer_' . $_ } = do{ my $x = '' };
    }
    $settings{'channels'} ||= 0;
    $settings{'gain'} ||= 0;
    $settings{'debug'} ||= 0;
    return Nick::Audio::MAD -> new_xs(
        @settings{ qw(
            buffer_in buffer_out channels gain debug
        ) }
    );
}

1;
