#include <common.h>

// N = 4, 8, or 16, which is the channel group size. 
__kernel void convolution(__global const DATA_TYPE* restrict input,   /* [ic/N, ih, iw, N] */
                          __global const DATA_TYPE* restrict weights, /* [oc/N, ic/N, kh, kw, N, N] */
#ifdef BIAS                                                                                /* i, o */
                          __global const DATA_TYPE* restrict bias,    /* [oc] */
#endif
                          __global DATA_TYPE* restrict output,        /* [oc/N, oh, ow, N] */
                          __private const int input_channels,         /* a multiple of N */
                          __private const int output_channels,        /* a multiple of N */
                          __private const int input_height,
                          __private const int input_width,
                          __private const int output_height,
                          __private const int output_width,
                          __private const int kernel_height,
                          __private const int kernel_width,
                          __private const int stride_height,
                          __private const int stride_width,
                          __private const int padding_top,
                          __private const int padding_left) {
  const int out_height_idx = get_global_id(0);
  const int out_width_idx = get_global_id(1);
  if (out_height_idx >= output_height || out_width_idx >= output_width) return;
  const int out_channel_group_idx = get_global_id(2);
  const int out_channel_idx = mul24(out_channel_group_idx, N);

  int in_height_beg = mad24(out_height_idx, stride_height, -padding_top);
  int in_height_end = in_height_beg + kernel_height;
  const int kernel_height_beg_gap = select(0, -in_height_beg, in_height_beg < 0);
  const int kernel_height_end_gap = select(0, in_height_end - input_height, in_height_end > input_height);
  in_height_beg = max(0, in_height_beg);
  in_height_end = min(in_height_end, input_height);
  int in_width_beg = mad24(out_width_idx, stride_width, -padding_left);
  int in_width_end = in_width_beg + kernel_width;
  const int kernel_width_beg_gap = select(0, -in_width_beg, in_width_beg < 0);
  const int kernel_width_end_gap = select(0, in_width_end - input_width, in_width_end > input_width);
  in_width_beg = max(0, in_width_beg);
  in_width_end = min(in_width_end, input_width);

  const int in_height_size = mul24(input_width, N);
  const int in_height_beg_gap_size = mul24(in_height_beg, in_height_size);
  const int in_height_end_gap_size = mul24(input_height - in_height_end, in_height_size);
  const int in_height_gap_size = in_height_beg_gap_size + in_height_end_gap_size;
  const int in_width_beg_gap_size = mul24(in_width_beg, N);
  const int in_width_end_gap_size = mul24(input_width - in_width_end, N);
  const int in_width_gap_size = in_width_beg_gap_size + in_width_end_gap_size;
  int in_val_idx = in_height_beg_gap_size + in_width_beg_gap_size;

  const int kernel_width_size = mul24(N, N);
  const int kernel_height_size = mul24(kernel_width, kernel_width_size);
  const int kernel_height_beg_gap_size = mul24(kernel_height_beg_gap, kernel_height_size);
  const int kernel_height_end_gap_size = mul24(kernel_height_end_gap, kernel_height_size);
  const int kernel_height_gap_size = kernel_height_beg_gap_size + kernel_height_end_gap_size;
  const int kernel_width_beg_gap_size = mul24(kernel_width_beg_gap, kernel_width_size);
  const int kernel_width_end_gap_size = mul24(kernel_width_end_gap, kernel_width_size);
  const int kernel_width_gap_size = kernel_width_beg_gap_size + kernel_width_end_gap_size;
  const int kernel_size = mul24(mul24(kernel_height, kernel_width), input_channels);
  int kernel_val_idx = mad24(out_channel_idx, kernel_size, kernel_height_beg_gap_size) 
                       + kernel_width_beg_gap_size;

  DATA_TYPEN in_val, kernel_val;
#ifdef BIAS
  DATA_TYPEN out_val = VLOADN(0, &bias[out_channel_idx]);
#else
  DATA_TYPEN out_val = 0;
#endif
  for (int in_channel_idx = 0; in_channel_idx != input_channels; in_channel_idx += N) {
    for (int in_height_idx = in_height_beg; in_height_idx != in_height_end; ++in_height_idx) {
      for (int in_width_idx = in_width_beg; in_width_idx != in_width_end; ++in_width_idx) {
        in_val = VLOADN(0, &input[in_val_idx]);
        in_val_idx += N;

#define LOAD_KERNEL_AND_CALC(i)                           \
        kernel_val = VLOADN(0, &weights[kernel_val_idx]); \
        out_val = mad(in_val.s##i, kernel_val, out_val);  \
        kernel_val_idx += N;

        LOAD_KERNEL_AND_CALC(0);
        LOAD_KERNEL_AND_CALC(1);
        LOAD_KERNEL_AND_CALC(2);
        LOAD_KERNEL_AND_CALC(3);
#if N == 8 || N == 16
        LOAD_KERNEL_AND_CALC(4);
        LOAD_KERNEL_AND_CALC(5);
        LOAD_KERNEL_AND_CALC(6);
        LOAD_KERNEL_AND_CALC(7);
#if N == 16
        LOAD_KERNEL_AND_CALC(8);
        LOAD_KERNEL_AND_CALC(9);
        LOAD_KERNEL_AND_CALC(a);
        LOAD_KERNEL_AND_CALC(b);
        LOAD_KERNEL_AND_CALC(c);
        LOAD_KERNEL_AND_CALC(d);
        LOAD_KERNEL_AND_CALC(e);
        LOAD_KERNEL_AND_CALC(f);
#endif
#endif

#undef LOAD_KERNEL_AND_CALC
      }

      in_val_idx += in_width_gap_size;
      kernel_val_idx += kernel_width_gap_size;
    }

    in_val_idx += in_height_gap_size;
    kernel_val_idx += kernel_height_gap_size;
  }

#if defined(USE_RELU)
  out_val = fmax(out_val, (DATA_TYPE)0);
#endif

  const int out_val_idx = mul24(N, mad24(mad24(out_channel_group_idx, 
                                               output_height, 
                                               out_height_idx),
                                         output_width,
                                         out_width_idx));
  VSTOREN(out_val, 0, &output[out_val_idx]);
}
