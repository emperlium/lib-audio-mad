struct audio_stats {
  unsigned long clipped_samples;
  mad_fixed_t peak_clipping;
  mad_fixed_t peak_sample;
};

struct audio_dither {
  mad_fixed_t error[3];
  mad_fixed_t random;
};

signed long audio_linear_dither(
    mad_fixed_t,
    struct audio_dither *,
    struct audio_stats *
);
