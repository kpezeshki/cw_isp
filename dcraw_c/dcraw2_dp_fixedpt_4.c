
#include "dcraw2_dp.h"
#include <stdio.h>


/* Global Varaible definitions */

FILE *ifp, *ofp;
short order;
const char *ifname;
char *meta_data, xtrans[6][6], xtrans_abs[6][6];
char cdesc[5], desc[512], make[64], model[64], model2[64], artist[64];
float flash_used, canon_ev, iso_speed, shutter, aperture, focal_len;
time_t timestamp;
off_t strip_offset, data_offset;
off_t thumb_offset, meta_offset, profile_offset;
unsigned shot_order, kodak_cbpp, exif_cfa, unique_id;
unsigned thumb_length, meta_length, profile_length;
unsigned thumb_misc, *oprof, fuji_layout, shot_select=0, multi_out=0;
unsigned tiff_nifds, tiff_samples, tiff_bps, tiff_compress;
unsigned black, maximum, mix_green, raw_color, zero_is_bad;
unsigned zero_after_ff, is_raw, dng_version, is_foveon, data_error;
unsigned tile_width, tile_length, gpsdata[32], load_flags;
unsigned flip, tiff_flip, filters, colors;
ushort raw_height, raw_width, height, width, top_margin, left_margin;
ushort shrink, iheight, iwidth, fuji_width, thumb_width, thumb_height;
ushort *raw_image, (*image)[4], cblack[4102];
ushort white[8][8], curve[0x10000], cr2_slice[3], sraw_mul[4];
float bright=1, user_mul[4]={0,0,0,0}, threshold=0;
int mask[8][4];
int half_size=0, four_color_rgb=0, document_mode=0, highlight=0;
int verbose=0, use_auto_wb=0, use_camera_wb=0, use_camera_matrix=1;
int output_color=1, output_bps=8, output_tiff=0, med_passes=0;
int no_auto_bright=0;

unsigned greybox[4] = { 0, 0, UINT_MAX, UINT_MAX };

float cam_mul[4], pre_mul[4], cmatrix[3][4], rgb_cam[3][4];
const float d65_white[3] = { 0.950456, 1, 1.088754 };
int histogram[4][0x2000];
void (*write_thumb)(), (*write_fun)();
void (*load_raw)(), (*thumb_load_raw)();

float out_cam[3][4];

/* Functions */
void CLASS convert_to_rgb_dp()
// applies camera profile and converts to output color space
{
  int row, col, c, i, j, k;
  ushort *img;
  float out[3];
	
  // M4c: convert the image to the output space
  // convert the interpolated image from the camera space to the output space
  memset (histogram, 0, sizeof histogram);
  // height (h)
  for (img=image[0], row=0; row < height; row++)
    // width (w)
    for (col=0; col < width; col++, img+=4) {
      if (!raw_color) {
	out[0] = out[1] = out[2] = 0;
	// 3c multiplies, 3(c-1) adds, c=colors=3
	// for (c=0; c < colors; c++)
	FORCC {
	  // setting each color channel value (e.g. R, G, or B) by multiplying interpolated image color channels 
	  // by out_cam (which converts image from camera space to output space)
	  out[0] += out_cam[0][c] * img[c];
	  out[1] += out_cam[1][c] * img[c];
	  out[2] += out_cam[2][c] * img[c];
	}
	// for (c=0; c < 3; c++)
	// CLIP clips image to be between 0 and 65535
	FORC3 img[c] = CLIP((int) out[c]);
      }
      // for (c=0; c < colors; c++)
      FORCC histogram[c][img[c] >> 3]++;
    }
  if (colors == 4 && output_color) colors = 3;
}

void CLASS pre_interpolate()
{
  ushort (*img)[4];
  int row, col, c;

  if (shrink) {
    if (half_size) {
      height = iheight;
      width  = iwidth;
      if (filters == 9) {
	for (row=0; row < 3; row++)
	  for (col=1; col < 4; col++)
	    if (!(image[row*width+col][0] | image[row*width+col][2]))
	      goto break2;  break2:
	for ( ; row < height; row+=3)
	  for (col=(col-1)%3+1; col < width-1; col+=3) {
	    img = image + row*width+col;
	    for (c=0; c < 3; c+=2)
	      img[0][c] = (img[-1][c] + img[1][c]) >> 1;
	  }
      }
    } else {
      img = (ushort (*)[4]) calloc (height, width*sizeof *img);
      merror (img, "pre_interpolate()");
      for (row=0; row < height; row++)
	for (col=0; col < width; col++) {
	  c = fcol(row,col);
	  img[row*width+col][c] = image[(row >> 1)*iwidth+(col >> 1)][c];
	}
      free (image);
      image = img;
      shrink = 0;
    }
  }
  if (filters > 1000 && colors == 3) {
    mix_green = four_color_rgb ^ half_size;
    if (four_color_rgb | half_size) colors++;
    else {
      for (row = FC(1,0) >> 1; row < height; row+=2)
	for (col = FC(row,1) & 1; col < width; col+=2)
	  image[row*width+col][1] = image[row*width+col][3];
      filters &= ~((filters & 0x55555555) << 1);
    }
  }
  if (half_size) filters = 0;
}

int CLASS my_fcol(int row, int col){
    int a,b;
    a = row & 1;
    b = col & 1;
    if (a==0 && b==0) return 0;
    else if (a==1 && b==1) return 2;
    else return 1;
}

void CLASS border_interpolate (int border)
{
/*
  unsigned row, col, y, x, f, c, sum[8];

  for (row=0; row < height; row++)
    for (col=0; col < width; col++) {
      if (col==border && row >= border && row < height-border)
	col = width-border;
      memset (sum, 0, sizeof sum);
      for (y=row-1; y != row+2; y++)
	for (x=col-1; x != col+2; x++)
	  if (y < height && x < width) {
	    f = my_fcol(y,x);
	    sum[f] += image[y*width+x][f];
	    sum[f+4]++;
	  }
      f = my_fcol(row,col);
      FORCC if (c != f && sum[c+4]){
        if (sum[c+4] == 1) image[row*width+col][c] = sum[c];
        else if (sum[c+4] == 2) image[row*width+col][c] = sum[c] * 0.5;
        else if (sum[c+4] == 3) image[row*width+col][c] = sum[c] *(1.0/ 3) ;
        else if (sum[c+4] == 4) image[row*width+col][c] = sum[c] * 0.25;
        //else image[row*width+col][c] = sum[c] / sum[c+4];
        }
    }
*/
}

void CLASS lin_interpolate()
{
  unsigned row, col, y, x, f, c, sum[8];

  FILE *fw;
  ushort* ptr;
  fw = fopen("before.txt","w");

 
  ptr = image;
  for (row=0; row < height; row++){
    for (col=0; col < width; col++){
      fwrite(ptr,2,1,fw);
      ptr++;
      //fwrite(ptr,2,4,fw);
      //ptr++;
      //fwrite(ptr,2,4,fw);
      //ptr++;
      //fwrite(ptr,2,1,fw);
      //if (row!= height-1 && col!=width-1))ptr++;
    }
  }
/*
  printf("%x\n",image[0][0]);
    printf("%x\n",image[0][1]);
   printf("%x\n",image[0][2]);
 printf("%x\n",image[0][3]);
 printf("%x\n",image[1][0]);
 printf("%x\n",image[1][1]);
 printf("%x\n",image[1][2]);
 printf("%x\n",image[1][3]);
 printf("%x\n",image[2][0]);
 printf("%x\n",image[2][1]);
 printf("%x\n",image[2][2]);
 printf("%x\n",image[2][3]);
 printf("%x\n",image[3][0]);
 printf("%x\n",image[3][1]);
 printf("%x\n",image[3][2]);
 printf("%x\n",image[3][3]);
 printf("%x\n",image[width][0]);
 printf("%x\n",image[width][1]);
 printf("%x\n",image[width][2]);
 printf("%x\n",image[width][3]);

 printf("%x\n",image[width+1][0]);
 printf("%x\n",image[width+1][1]);
 printf("%x\n",image[width+1][2]);
 printf("%x\n",image[width+1][3]);
*/
  fclose(fw);
  for (row=0; row < height; row++)
    for (col=0; col < width; col++) {
      memset (sum, 0, sizeof sum);
      for (y=row-1; y != row+2; y++)
	for (x=col-1; x != col+2; x++)
	  if (y < height && x < width) {
	    f = my_fcol(y,x);
	    sum[f] += image[y*width+x][f];
	    sum[f+4]++;
	  }
      f = my_fcol(row,col);
      FORCC if (c != f && sum[c+4]){
        if (sum[c+4] == 1) image[row*width+col][c] = sum[c];
        else if (sum[c+4] == 2) image[row*width+col][c] = sum[c] * 0.5;
        else if (sum[c+4] == 3) image[row*width+col][c] = sum[c] *(1.0/ 3) ;
        else if (sum[c+4] == 4) image[row*width+col][c] = sum[c] * 0.25;
        //else image[row*width+col][c] = sum[c] / sum[c+4];
        }
    }
/*
  int code[16][16][32], size=16, *ip, sum[4];
  int f, c, i, x, y, row, col, shift, color;
  ushort *pix;

  //if (verbose) fprintf (stderr,_("Bilinear interpolation...\n"));
  if (filters == 9) size = 6;
  border_interpolate(1);
  for (row=0; row < size; row++)
    for (col=0; col < size; col++) {
      ip = code[row][col]+1;
      f = my_fcol(row,col);
      memset (sum, 0, sizeof sum);
      for (y=-1; y <= 1; y++)
	for (x=-1; x <= 1; x++) {
	  shift = (y==0) + (x==0);
	  color = my_fcol(row+y,col+x);
	  if (color == f) continue;
	  *ip++ = (width*y + x)*4 + color;
	  *ip++ = shift;
	  *ip++ = color;
	  sum[color] += 1 << shift;
	}
      code[row][col][0] = (ip - code[row][col]) / 3;
      FORCC
	if (c != f) {
	  *ip++ = c;
	  *ip++ = 256 / sum[c];
	}
    }
  for (row=1; row < height-1; row++)
    for (col=1; col < width-1; col++) {
      pix = image[row*width+col];
      ip = code[row % size][col % size];
      memset (sum, 0, sizeof sum);
      for (i=*ip++; i--; ip+=3)
	sum[ip[2]] += pix[ip[0]] << ip[1];
      for (i=colors; --i; ip+=2)
	pix[ip[0]] = sum[ip[0]] * ip[1] >> 8;
    }

*/
}


void CLASS scale_colors()
{
  unsigned bottom, right, size, row, col, ur, uc, i, x, y, c, sum[8];
  int val, dark, sat;
  double dsum[8], dmin, dmax;
  float scale_mul[4], fr, fc;
  ushort *img=0, *pix;
  int fixed_mul[4];
  int bit_shift = 4; // for conversion from float to fixed point

  // copy user specified multipliers into pre_mul
  if (user_mul[0])
    memcpy (pre_mul, user_mul, sizeof pre_mul);

  // set values for noise floor and maximum
  dark = black; // dark not used 
  sat = maximum; // sat not used
  maximum -= black; // black only used here

  // sets dmin to smallest multiplier,
  // sets dmax to largest multiplier
  for (dmin=DBL_MAX, dmax=c=0; c < 4; c++) {
    if (dmin > pre_mul[c]) // for pre_mul = {1 1 1 1}, always executes
	dmin = pre_mul[c];
    if (dmax < pre_mul[c]) // for pre_mul = {1 1 1 1}, always executes
	dmax = pre_mul[c];
  }
  // dmin = 1, dmax = 1 
  dmax = dmin;

  // Division can be taken out, replaced with a constant to multiply
  // maximum = determined by camera, set in adobe_coeff
  FORC4 scale_mul[c] = (pre_mul[c] /= dmax) * 65535.0 / maximum;

  FORC4 fixed_mul[c] = scale_mul[i] * (1 << bit_shift);

  size = iheight*iwidth;
  for (i=0; i < size*4; i++) {
    if (!(val = ((ushort *)image)[i])) continue;
    val -= cblack[i & 3];
    //val *= scale_mul[i & 3]; // floating point
    val = (val * fixed_mul[i & 3]) >> bit_shift;
// Clip integer value between 0 and 255 
   ((ushort *)image)[i] = CLIP(val);
  }
}







