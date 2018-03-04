void CLASS pre_interpolate()
{
  ushort (*img)[4];
  int row, col, c;

  if (shrink) {
    if (half_size) {
      height = iheight;
      width  = iwidth;
      // what does the filters variable indicate?
      if (filters == 9) {
        // loop in this 3x3 area where row is zeroed
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

void CLASS border_interpolate (int border)
{
  unsigned row, col, y, x, f, c, sum[8];

  // loop through all rows and columns of the image
  for (row=0; row < height; row++)
    for (col=0; col < width; col++) { // COUNT: height*width adds
      // if we are on the border column and the row is greater than the 
      // border but less that than the border height difference
      if (col==border && row >= border && row < height-border)
        // column is now the width minus border
        col = width-border;
      memset (sum, 0, sizeof sum);
      // loop over a 3x3 area
      for (y=row-1; y != row+2; y++)
        for (x=col-1; x != col+2; x++) // COUNT: 3*3 adds in 
          if (y < height && x < width) {
	         f = fcol(y,x);
           sum[f] += image[y*width+x][f]; // COUNT: 2 adds, 1 multiply 
                                          // in the 3*3 in height*width
           sum[f+4]++; // COUNT: 2 adds in the 3*3 in height*width
	        }

      f = fcol(row,col);
      FORCC if (c != f && sum[c+4])
	    image[row*width+col][c] = sum[c] / sum[c+4]; // COUNT: 2 adds, 1 multiply, 
                                                   // 1 divide
    }
}

// int CLASS fc (int row, int col)
// {
//   static const char filter[16][16] =
//   { { 2,1,1,3,2,3,2,0,3,2,3,0,1,2,1,0 },
//     { 0,3,0,2,0,1,3,1,0,1,1,2,0,3,3,2 },
//     { 2,3,3,2,3,1,1,3,3,1,2,1,2,0,0,3 },
//     { 0,1,0,1,0,2,0,2,2,0,3,0,1,3,2,1 },
//     { 3,1,1,2,0,1,0,2,1,3,1,3,0,1,3,0 },
//     { 2,0,0,3,3,2,3,1,2,0,2,0,3,2,2,1 },
//     { 2,3,3,1,2,1,2,1,2,1,1,2,3,0,0,1 },
//     { 1,0,0,2,3,0,0,3,0,3,0,3,2,1,2,3 },
//     { 2,3,3,1,1,2,1,0,3,2,3,0,2,3,1,3 },
//     { 1,0,2,0,3,0,3,2,0,1,1,2,0,1,0,2 },
//     { 0,1,1,3,3,2,2,1,1,3,3,0,2,1,3,2 },
//     { 2,3,2,0,0,1,3,0,2,0,1,2,3,0,1,0 },
//     { 1,3,1,2,3,2,3,2,0,2,0,1,1,0,3,0 },
//     { 0,2,0,3,1,0,0,1,1,3,3,2,3,2,2,1 },
//     { 2,1,3,2,3,1,2,1,0,3,0,2,0,2,0,2 },
//     { 0,3,1,0,0,2,0,3,2,1,3,1,1,3,1,3 } };

//   if (filters != 1) return FC(row,col);
//   return filter[(row+top_margin) & 15][(col+left_margin) & 15];
// }

// #define FC(row,col) \
//   (filters >> ((((row) << 1 & 14) + ((col) & 1)) << 1) & 3)


void CLASS lin_interpolate()
{
  int code[16][16][32], size=16, *ip, sum[4];
  int f, c, i, x, y, row, col, shift, color;
  ushort *pix;

  //if (verbose) fprintf (stderr,_("Bilinear interpolation...\n"));
  if (filters == 9) size = 6;
  border_interpolate(1);
  // loop trough rows and columns
  for (row=0; row < size; row++)
    for (col=0; col < size; col++) {
      // ip corresponds to an array in the third dimension, adding 1 note sure
      ip = code[row][col]+1;
      f = fcol(row,col);
      memset (sum, 0, sizeof sum);
      // one above and one below in both the x and y directions
      for (y=-1; y <= 1; y++)
      	for (x=-1; x <= 1; x++) {
      	  shift = (y==0) + (x==0);
      	  color = fcol(row+y,col+x);
      	  if (color == f) continue;
          // not sure why these operations performed on ip
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
  // loop through making sure to not loop on one of the edge pixels of the 
  // image 
  for (row=1; row < height-1; row++)
    for (col=1; col < width-1; col++) {
      // get the current pixel
      pix = image[row*width+col];
      ip = code[row % size][col % size];
      memset (sum, 0, sizeof sum);
      // still need to understand
      for (i=*ip++; i--; ip+=3)
	     sum[ip[2]] += pix[ip[0]] << ip[1];
      for (i=colors; --i; ip+=2)
	     pix[ip[0]] = sum[ip[0]] * ip[1] >> 8;
    }
}