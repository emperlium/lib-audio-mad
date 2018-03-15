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
