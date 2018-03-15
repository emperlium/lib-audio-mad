#include <mad.h>
#include "dither.h"

inline signed long audio_linear_dither(
    mad_fixed_t sample,
    struct audio_dither *dither,
    struct audio_stats *stats
) {
    unsigned int bits = 16;
    unsigned int scalebits;
    mad_fixed_t output, mask, random;

    enum {
        MIN = -MAD_F_ONE,
        MAX = MAD_F_ONE - 1
    };

    /* noise shape */
    sample += dither -> error[0] - dither -> error[1] + dither -> error[2];

    dither -> error[2] = dither -> error[1];
    dither -> error[1] = dither -> error[0] / 2;

    /* bias */
    output = sample + (1L << (MAD_F_FRACBITS + 1 - bits - 1));

    scalebits = MAD_F_FRACBITS + 1 - bits;
    mask = (1L << scalebits) - 1;

    /* dither */
    random = (
        dither -> random * 0x0019660dL + 0x3c6ef35fL
    ) & 0xffffffffL;

    output += ( random & mask ) - ( dither -> random & mask );

    dither -> random = random;

    /* clip */
    if ( output >= stats -> peak_sample ) {
        if ( output > MAX ) {
            ++stats -> clipped_samples;
            if ( output - MAX > stats -> peak_clipping ) {
                stats -> peak_clipping = output - MAX;
            }
            output = MAX;
            if ( sample > MAX ) {
                sample = MAX;
            }
        }
        stats->peak_sample = output;
    } else if ( output < -stats -> peak_sample ) {
        if ( output < MIN ) {
            ++stats -> clipped_samples;
            if ( MIN - output > stats -> peak_clipping ) {
                stats -> peak_clipping = MIN - output;
            }
            output = MIN;
            if ( sample < MIN ) {
                sample = MIN;
            }
        }
        stats -> peak_sample = -output;
    }

    /* quantize */
    output &= ~mask;

    /* error feedback */
    dither->error[0] = sample - output;

    /* scale */
    return output >> scalebits;
}
