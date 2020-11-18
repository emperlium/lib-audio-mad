#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <mad.h>
#include <math.h>

#include "dither.h"

struct nickaudiomad {
    struct mad_stream stream;
    struct mad_frame frame;
    struct mad_synth synth;
    void *pcm_out;
    SV *scalar_in;
    SV *scalar_out;
    unsigned char channels;
    mad_fixed_t gain;
    bool debug;
    struct audio_dither left_dither;
    struct audio_dither right_dither;
    struct audio_stats stats;
};

typedef struct nickaudiomad NICKAUDIOMAD;

#define MAX_SIZE 8192
#define MAX_BUFFER 65536

MODULE = Nick::Audio::MAD  PACKAGE = Nick::Audio::MAD

static NICKAUDIOMAD *
NICKAUDIOMAD::new_xs( scalar_in, scalar_out, channels, gain, debug )
        SV *scalar_in;
        SV *scalar_out;
        unsigned char channels;
        float gain;
        bool debug;
    CODE:
        Newxz( RETVAL, 1, NICKAUDIOMAD );
        mad_stream_init(
            &( RETVAL -> stream )
        );
        mad_frame_init(
            &( RETVAL -> frame )
        );
        mad_synth_init(
            &( RETVAL -> synth )
        );
        Newx( RETVAL -> pcm_out, MAX_SIZE, void );
        RETVAL -> scalar_in = SvREFCNT_inc(
            SvROK( scalar_in )
            ? SvRV( scalar_in )
            : scalar_in
        );
        RETVAL -> scalar_out = SvREFCNT_inc(
            SvROK( scalar_out )
            ? SvRV( scalar_out )
            : scalar_out
        );
        RETVAL -> channels = channels;
        RETVAL -> gain = mad_f_tofixed(
            pow( 10, gain / 20 )
        );
        RETVAL -> debug = debug;
    OUTPUT:
        RETVAL

void
NICKAUDIOMAD::DESTROY()
    CODE:
        mad_synth_finish(
            &( THIS -> synth )
        );
        mad_frame_finish(
            &( THIS -> frame )
        );
        mad_stream_finish(
            &( THIS -> stream )
        );
        SvREFCNT_dec( THIS -> scalar_in );
        SvREFCNT_dec( THIS -> scalar_out );
        Safefree( THIS -> pcm_out );
        Safefree( THIS );

void
NICKAUDIOMAD::set_buffer_in_ref( scalar_in )
        SV *scalar_in;
    CODE:
        SvREFCNT_dec( THIS -> scalar_in );
        THIS -> scalar_in = SvREFCNT_inc(
            SvROK( scalar_in )
            ? SvRV( scalar_in )
            : scalar_in
        );

void
NICKAUDIOMAD::set_buffer_out_ref( scalar_out )
        SV *scalar_out;
    CODE:
        SvREFCNT_dec( THIS -> scalar_out );
        THIS -> scalar_out = SvREFCNT_inc(
            SvROK( scalar_out )
            ? SvRV( scalar_out )
            : scalar_out
        );

int
NICKAUDIOMAD::decode( flush=false )
        bool flush;
    CODE:
        if (
            ! SvOK( THIS -> scalar_in )
        ) {
            sv_setpvn( THIS -> scalar_out, NULL, 0 );
            XSRETURN_UNDEF;
        }
        STRLEN len_in;
        unsigned char *in_buff = SvPV( THIS -> scalar_in, len_in );
        if ( len_in > MAX_BUFFER ) {
            croak( "MAD decode buffer too big: %d", len_in );
        }
        if ( flush ) {
            SvGROW( THIS -> scalar_in, len_in + MAD_BUFFER_GUARD );
            memset( in_buff + len_in, 0, MAD_BUFFER_GUARD );
            len_in += MAD_BUFFER_GUARD;
        }
        mad_stream_buffer(
            &( THIS -> stream ),
            in_buff,
            (unsigned long)len_in
        );
        struct mad_frame *frame = &( THIS -> frame );
        struct mad_stream *stream = &( THIS -> stream );
        if (
            mad_frame_decode( frame, stream ) == -1
        ) {
            int error = stream -> error;
            if (
                error == MAD_ERROR_BUFLEN
            ) {
                RETVAL = 0;
            } else if (
                MAD_RECOVERABLE( error )
            ) {
                if (
                    error != MAD_ERROR_LOSTSYNC
                    &&
                    stream -> bufend > stream -> next_frame
                ) {
                    if ( THIS -> debug ) {
                        warn(
                            "Clearing MAD buffer of %lu bytes (error %x)\n",
                            stream -> bufend - stream -> next_frame,
                            error
                        );
                    }
                    sv_setpvn(
                        THIS -> scalar_in,
                        stream -> next_frame,
                        stream -> bufend - stream -> next_frame
                    );
                } else {
                    if ( THIS -> debug ) {
                        warn(
                            "Emptying MAD buffer of %d bytes (error %x)\n",
                            (int)len_in, error
                        );
                    }
                    sv_setpvn( THIS -> scalar_in, "", 0 );
                }
                RETVAL = 0;
            } else {
                croak( "MAD decode error: %x", error );
            }
        } else {
            if ( THIS -> gain != MAD_F_ONE ) {
                unsigned int nch, ch, ns, s, sb;
                nch = MAD_NCHANNELS( &frame -> header );
                ns  = MAD_NSBSAMPLES( &frame -> header );
                for ( ch = 0; ch < nch; ++ch ) {
                    for ( s = 0; s < ns; ++s ) {
                        for ( sb = 0; sb < 32; ++sb ) {
                            frame -> sbsample[ch][s][sb] = mad_f_mul(
                                frame -> sbsample[ch][s][sb],
                                THIS -> gain
                            );
                        }
                    }
                }
            }
            if ( THIS -> channels == 1 ) {
                if (
                    frame -> header.mode != MAD_MODE_SINGLE_CHANNEL
                ) {
                    unsigned int ns, s, sb;
                    ns  = MAD_NSBSAMPLES( &frame -> header );
                    for ( s = 0; s < ns; ++s ) {
                        for ( sb = 0; sb < 32; ++sb ) {
                            frame -> sbsample[0][s][sb] = (
                                frame -> sbsample[0][s][sb]
                                + frame -> sbsample[1][s][sb]
                            ) / 2;
                        }
                    }
                    frame -> header.mode = MAD_MODE_SINGLE_CHANNEL;
                }
            } else if ( THIS -> channels == 2 ) {
                if (
                    frame -> header.mode == MAD_MODE_SINGLE_CHANNEL
                ) {
                    unsigned int ns, s, sb;
                    ns  = MAD_NSBSAMPLES( &frame -> header );
                    for ( s = 0; s < ns; ++s ) {
                        for ( sb = 0; sb < 32; ++sb ) {
                            frame -> sbsample[1][s][sb]
                                = frame -> sbsample[0][s][sb];
                        }
                    }
                    frame -> header.mode = MAD_MODE_STEREO;
                }
            }
            mad_synth_frame(
                &( THIS -> synth ), frame
            );
            sv_setpvn(
                THIS -> scalar_in,
                stream -> next_frame,
                stream -> bufend - stream -> next_frame
            );
            struct mad_pcm *pcm = &( THIS -> synth.pcm );
            unsigned int len = pcm -> length;
            unsigned char *data = THIS -> pcm_out;
            if ( pcm -> channels == 2 ) {
                mad_fixed_t const *left_ch = pcm -> samples[0],
                                    *right_ch = pcm -> samples[1];
                register signed int sample_l, sample_r;
                RETVAL = len * 4;
                while ( len-- ) {
                    sample_l = audio_linear_dither(
                        *left_ch++,
                        &( THIS -> left_dither ),
                        &( THIS -> stats )
                    );
                    sample_r = audio_linear_dither(
                        *right_ch++,
                        &( THIS -> right_dither ),
                        &( THIS -> stats )
                    );
                    data[0] = sample_l >> 0;
                    data[1] = sample_l >> 8;
                    data[2] = sample_r >> 0;
                    data[3] = sample_r >> 8;
                    data += 4;
                }
            } else {
                mad_fixed_t const *left_ch = pcm -> samples[0];
                register signed int sample;
                RETVAL = len * 2;
                while ( len-- ) {
                    sample = audio_linear_dither(
                        *left_ch++,
                        &( THIS -> left_dither ),
                        &( THIS -> stats )
                    );
                    data[0] = sample >> 0;
                    data[1] = sample >> 8;
                    data += 2;
                }
            }
            sv_setpvn( THIS -> scalar_out, THIS -> pcm_out, RETVAL );
        }
    OUTPUT:
        RETVAL
