

#include <stdio.h>
#include <time.h>
#include <sys/types.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <setjmp.h>
#include <stdlib.h>
#include <string.h>


#if !defined(uchar)
#define uchar unsigned char
#endif
#if !defined(ushort)
#define ushort unsigned short
#endif



/* Global Varaible declarations */

extern FILE *ifp, *ofp;
extern short order;
extern const char *ifname;
extern char *meta_data, xtrans[6][6], xtrans_abs[6][6];
extern char cdesc[5], desc[512], make[64], model[64], model2[64], artist[64];
extern float flash_used, canon_ev, iso_speed, shutter, aperture, focal_len;
extern time_t timestamp;
extern off_t strip_offset, data_offset;
extern off_t thumb_offset, meta_offset, profile_offset;
extern unsigned shot_order, kodak_cbpp, exif_cfa, unique_id;
extern unsigned thumb_length, meta_length, profile_length;
extern unsigned thumb_misc, *oprof, fuji_layout, shot_select, multi_out;
extern unsigned tiff_nifds, tiff_samples, tiff_bps, tiff_compress;
extern unsigned black, maximum, mix_green, raw_color, zero_is_bad;
extern unsigned zero_after_ff, is_raw, dng_version, is_foveon, data_error;
extern unsigned tile_width, tile_length, gpsdata[32], load_flags;
extern unsigned flip, tiff_flip, filters, colors;
extern ushort raw_height, raw_width, height, width, top_margin, left_margin;
extern ushort shrink, iheight, iwidth, fuji_width, thumb_width, thumb_height;
extern ushort *raw_image, (*image)[4], cblack[4102];
extern ushort white[8][8], curve[0x10000], cr2_slice[3], sraw_mul[4];
extern double pixel_aspect, aber[4], gamm[6];
extern float bright, user_mul[4], threshold;
extern int mask[8][4];
extern int half_size, four_color_rgb, document_mode, highlight;
extern int verbose, use_auto_wb, use_camera_wb, use_camera_matrix;
extern int output_color, output_bps, output_tiff, med_passes;
extern int no_auto_bright;

extern unsigned greybox[4];

extern float cam_mul[4], pre_mul[4], cmatrix[3][4], rgb_cam[3][4];
extern const double xyz_rgb[3][3];
extern const float d65_white[3];
extern int histogram[4][0x2000];
extern void (*write_thumb)(), (*write_fun)();
extern void (*load_raw)(), (*thumb_load_raw)();

float out_cam[3][4];

#define CLASS

#define FORC(cnt) for (c=0; c < cnt; c++)
#define FORC3 FORC(3)
#define FORC4 FORC(4)
#define FORCC FORC(colors)

#define SQR(x) ((x)*(x))
#define ABS(x) (((int)(x) ^ ((int)(x) >> 31)) - ((int)(x) >> 31))
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define LIM(x,min,max) MAX(min,MIN(x,max))
#define ULIM(x,y,z) ((y) < (z) ? LIM(x,y,z) : LIM(x,z,y))
#define CLIP(x) LIM((int)(x),0,65535)
#define SWAP(a,b) { a=a+b; b=a-b; a=a-b; }

#define RAW(row,col) \
	raw_image[(row)*raw_width+(col)]

#define FC(row,col) \
	(filters >> ((((row) << 1 & 14) + ((col) & 1)) << 1) & 3)

#define BAYER(row,col) \
	image[((row) >> shrink)*iwidth + ((col) >> shrink)][FC(row,col)]

#define BAYER2(row,col) \
	image[((row) >> shrink)*iwidth + ((col) >> shrink)][fcol(row,col)]

#ifndef __GLIBC__
char *my_memmem (char *haystack, size_t haystacklen,
	      char *needle, size_t needlelen)
{
  char *c;
  for (c = haystack; c <= haystack + haystacklen - needlelen; c++)
    if (!memcmp (c, needle, needlelen))
      return c;
  return 0;
}
#define memmem my_memmem
char *my_strcasestr (char *haystack, const char *needle)
{
  char *c;
  for (c = haystack; *c; c++)
    if (!strncasecmp(c, needle, strlen(needle)))
      return c;
  return 0;
}
#define strcasestr my_strcasestr
#endif


/* Prototypes for the functions */

void CLASS convert_to_rgb_dp();

void CLASS pre_interpolate();
void CLASS border_interpolate (int border);
void CLASS lin_interpolate();

void CLASS scale_colors();






