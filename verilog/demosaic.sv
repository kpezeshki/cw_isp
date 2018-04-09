
module demosaic #()
(   input logic clk,
    input logic reset,
    input logic[15:0] FWIDTH,
    input logic[15:0] FHEIGHT,
    input logic[15:0] crop_width,
    input logic[15:0] crop_height,
    //input logic[7:0] BITS_PER_RAW,
    //input logic[7:0] BAYER,
    input logic[15:0] read_data,
    output logic data_v,
    output logic[15:0] red,green,blue,
    output logic[31:0] adr,
    //output logic mem_write,
    output logic[1:0] position_read,
    output logic done);

    logic[2:0][63:0] top3, mid3, bot3;
    logic [15:0] row_read, col_read, row_read_crop, col_read_crop;
    logic [15:0] col_write, col_shift, row_calc, col_calc;
    logic end_of_row;
    logic next1, next2, next3;
    logic col_read_en, row_read_en;
    logic col_read_reset;
    logic col_write_reset, col_write_en;
    logic linebuf1_reset, linebuf2_reset, linebuf3_reset;
    logic col_shift_en, col_shift_reset;
    logic pixel_buffer_en;
    logic col_calc_reset, col_calc_en;
    logic [7:0] green_bitshift, red_bitshift, blue_bitshift;
    logic [15:0] green_mult;
    logic [63:0] linebuf_pixel1, linebuf_pixel2, linebuf_pixel3;
    logic [63:0] read_data_zero;
    logic [1:0] position;
    logic pixel_buffer_reset, pixel_buffer_reset_top,pixel_buffer_reset_bot;

    // row_read, col_read = current row/column we are reading


    /*****************************************
     * round robin logic
     *****************************************/
    always_ff@(posedge clk, posedge reset)
        if (reset) begin
            next1 <= 0;
            next2 <= 0;
            next3 <= 1;
        end
        // if we are in the first row or we reached the last of the row
        else if (row_read_en) begin
            // next line buffer logic 
            if (next1) begin
                next1 <= 0;
                next2 <= 1;
                next3 <= 0;
            end
            else if (next2) begin
                next1 <= 0;
                next2 <= 0;
                next3 <= 1;
            end
            else if (next3) begin
                next1 <= 1;
                next2 <= 0;
                next3 <= 0;
            end
        end

    /*****************************************
     * col_read, row_read, 
     * col_shift,
     * col_calc, row_calc logic
     *****************************************/
     
    logic end_of_first_row;
    assign end_of_first_row = (row_read == 0 && col_write == FWIDTH - 1);

    // if we are not in the next to last column, increment col_read
    assign col_read_reset = reset || end_of_first_row || end_of_row;
    assign col_read_en = (col_read != FWIDTH-1);

    assign col_write_reset = reset || end_of_first_row || end_of_row;
    assign col_write_en = (col_read != 0 && col_write != FWIDTH - 1);    

    // if we are in the first row or we reached the last of the row, increment row_read
    assign row_read_en = end_of_first_row || end_of_row;

    assign col_shift_reset = reset || end_of_first_row || end_of_row;
    assign col_shift_en = (col_write != 0) && (col_shift != FWIDTH); 
 
    assign col_calc_reset = reset || end_of_row;
    assign col_calc_en = (row_read != 0 && col_shift != 0 && col_shift != 1);

    addOne #(16) col_read_counter(clk, col_read_reset, col_read_en, col_read);
    addOne #(16) row_read_counter(clk, reset, row_read_en, row_read);

    addOne #(16) col_write_counter(clk,col_write_reset,col_write_en,col_write);

    addOne #(16) col_shift_counter(clk, col_shift_reset, col_shift_en, col_shift);

    addOne #(16) col_calc_counter(clk, col_calc_reset, col_calc_en, col_calc);
    addOne #(16) row_calc_counter(clk, reset, end_of_row, row_calc);

    assign end_of_row = (col_calc == FWIDTH - 1);
    assign position = {row_calc[0],col_calc[0]};
    assign position_read = {row_read_crop[0],col_read_crop[0]};

    /*****************************************
     * line buffer logic 
     *****************************************/

    assign read_data_zero = (row_read < FHEIGHT) ? read_data : 0;

    line_buffer linebuf1(clk, next1, col_shift, col_write, read_data_zero, linebuf_pixel1);
    line_buffer linebuf2(clk, next2, col_shift, col_write, read_data_zero, linebuf_pixel2);
    line_buffer linebuf3(clk, next3, col_shift, col_write, read_data_zero, linebuf_pixel3);
    
    assign row_read_crop = row_read + crop_height;
    assign col_read_crop = col_read + crop_width;
    assign adr = 32'h10000 + row_read_crop*(FWIDTH+crop_width) + col_read_crop;

    /*****************************************
     * 3-pixel buffer logic 
     *****************************************/

    always_ff@(posedge clk)
        if (reset || end_of_row || end_of_first_row) begin
            top3[2:1] <= 0;
            mid3[2:1] <= 0;
            bot3[2:1] <= 0;
        end
        else begin
            top3[2:1] <= top3[1:0];
            mid3[2:1] <= mid3[1:0];
            bot3[2:1] <= bot3[1:0];
        end

    assign pixel_buffer_reset = reset || (col_shift == FWIDTH) || end_of_row || end_of_first_row || col_write == 0;
    assign pixel_buffer_reset_top = pixel_buffer_reset || row_calc == 0;

    pixel_buffer #(64) top3_flop(clk, pixel_buffer_reset_top, next1, next2, next3,
                            linebuf_pixel2, 
                            linebuf_pixel3, 
                            linebuf_pixel1, top3[0]);
    pixel_buffer #(64) mid3_flop(clk, pixel_buffer_reset, next1, next2, next3,
                            linebuf_pixel3, 
                            linebuf_pixel1, 
                            linebuf_pixel2, mid3[0]);
    pixel_buffer #(64) bot3_flop(clk, pixel_buffer_reset, next1, next2, next3,
                            linebuf_pixel1, 
                            linebuf_pixel2, 
                            linebuf_pixel3, bot3[0]);


    /*****************************************
     * Neighbor averaging logic 
     *****************************************/
    logic [31:0] temp_green;
    logic [31:0] temp_green2;
    assign temp_green = (mid3[0]+mid3[2]+top3[1]+bot3[1]) * green_mult;
    assign temp_green2 = temp_green >> green_bitshift;

    always_comb
        case(position)
            2'b00:
                begin
                    red = mid3[1];
                    green = temp_green2[15:0];
                    blue = (top3[0]+top3[2]+bot3[0]+bot3[2]) >> blue_bitshift;
                end
            2'b01:
                begin
                    red = (mid3[0]+mid3[2]) >> red_bitshift;
                    green = mid3[1];
                    blue = (top3[1]+bot3[1]) >> blue_bitshift;
                end
            2'b10:
                begin
                    red = (top3[1]+bot3[1]) >> red_bitshift;
                    green = mid3[1];
                    blue = (mid3[0]+mid3[2]) >> blue_bitshift;
                end
            2'b11:
                begin
                    red = (top3[0]+top3[2]+bot3[0]+bot3[2]) >> red_bitshift;
                    green = temp_green2[15:0];
                    blue = mid3[1];
                end
        endcase

    /*****************************************
     * multipliers logic 
     *****************************************/

    // red_bitshift
    always_comb
        case(position)
            2'b00:
                red_bitshift = 0;
            2'b01:
                if (col_calc == FWIDTH - 1) red_bitshift = 0;
                else red_bitshift = 1;
            2'b10:
                if (row_calc == FHEIGHT - 1) red_bitshift = 0;
                else red_bitshift = 1;
            2'b11:
                if (row_calc == FHEIGHT - 1 && col_calc == FWIDTH - 1) red_bitshift = 0;
                else if (row_calc == FHEIGHT - 1 || col_calc == FWIDTH - 1) red_bitshift = 1;
                else red_bitshift = 2;
        endcase

    // green_bitshift
    always_comb
        case(position)
            2'b00:
                if (row_calc == 0 && col_calc == 0) green_bitshift = 1;
                else if (row_calc == 0 || col_calc == 0) green_bitshift = 16;
                else green_bitshift = 2;
            2'b01:
                  green_bitshift = 0;
            2'b10:
                  green_bitshift = 0;
            2'b11:
                if (row_calc == FHEIGHT - 1 && col_calc == FWIDTH - 1) green_bitshift = 1;
                else if (row_calc == FHEIGHT - 1 || col_calc == FWIDTH - 1) green_bitshift = 16;
                else green_bitshift = 2;
        endcase

    // green_mult
    always_comb
        case(position)
          2'b00:
              if (row_calc == 0 ^ col_calc == 0) green_mult = 21845;
              else green_mult = 1;
          2'b11:
              if (row_calc == FHEIGHT-1 ^ col_calc == FWIDTH-1) green_mult = 21845;
              else green_mult = 1;
          default:
              green_mult = 1;
        endcase 

    // blue_bitshift
    always_comb
        case(position)
            2'b00:
                if (row_calc == 0 && col_calc == 0) blue_bitshift = 0;
                else if (row_calc == 0 || col_calc == 0) blue_bitshift = 1;
                else blue_bitshift = 2;
            2'b01:
                if (row_calc == 0) blue_bitshift = 0;
                else blue_bitshift = 1;
            2'b10:
                if (col_calc == 0) blue_bitshift = 0;
                else blue_bitshift = 1;
            2'b11:
                blue_bitshift = 0;
        endcase
 
    /*****************************************
     * Data valid and Done signal
     *****************************************/

    assign data_v = (row_read != 0) && (col_shift != 0) && (col_shift != 1);
    assign done = (row_calc == FHEIGHT - 1) && end_of_row;

endmodule



module addOne #(parameter DATA_WIDTH=16) 
  ( input  logic clk,
    input  logic reset,
    input  logic en,
    output logic [DATA_WIDTH-1:0] q);

  always_ff@(posedge clk)
    if (reset)   q <= 0;
    else if (en) q <= q+1; 
  
endmodule

module pixel_buffer #(parameter DATA_WIDTH=16)
  ( input  logic clk,
    input  logic reset, 
    input  logic en1,
    input  logic en2,
    input  logic en3,
    input  logic [DATA_WIDTH-1:0] d1,
    input  logic [DATA_WIDTH-1:0] d2,
    input  logic [DATA_WIDTH-1:0] d3,
    output logic [DATA_WIDTH-1:0] q);

  always_ff@(posedge clk)
    if (reset)  q <= 0;
    else if (en1) q <= d1;
    else if (en2) q <= d2;
    else if (en3) q <= d3;

endmodule 


module line_buffer 
  (input logic clk,
   input logic we,
   input logic [15:0] read_adr,
   input logic [15:0] write_adr,
   input logic [63:0] data_in,
   output logic [63:0] data_out);

  logic [10000:0][63:0] linebuf;

  always_ff@(posedge clk)
    if (we) linebuf[write_adr] <= data_in;
  assign data_out = linebuf[read_adr];

endmodule



// D Flip-flop with enable and asynchronous reset
module flopenr #(parameter DATA_WIDTH=16)
              (input logic clk,
               input logic reset,
                input logic en,
               input logic [DATA_WIDTH-1:0] d,
               output logic [DATA_WIDTH-1:0] q);
    always_ff@(posedge clk, posedge reset)
        if    (reset)   q <= 0;
        else if (en)    q <= d;
endmodule

// D Flip-flop with asynchronous reset
module flopr #(parameter DATA_WIDTH=1)
             (input logic clk,
              input logic reset,
              input logic [DATA_WIDTH-1:0] d,
              output logic [DATA_WIDTH-1:0] q);
    always_ff@(posedge clk)
        if (reset)  q <= 0;
        else        q <= d;
endmodule

module white_balancing #(parameter FRACT_BITS = 8)
							 (input  logic clk, reset,
                                                          input  logic [1:0] position,
							  input  logic [63:0] pixel_in,
							  input  logic [15:0] wb_mult,
							  input  logic [15:0] cblack,
							  output logic [15:0] pixel_out);
	
	logic [31:0] after_mult;
	logic [16:0] after_cblack;
        logic [15:0] after_cblack_clipped;
	logic [31-FRACT_BITS:0] pixel_fixed; 
        logic [15:0] pixel_fixed_clipped;
        logic [15:0] read_data_muxed;


	always_ff @(posedge clk, posedge reset)
		if (reset) 	pixel_out <= 0;
		else 			pixel_out <= pixel_fixed_clipped;
		
	always_comb
		begin
			//fixed_mult = wb_mult << FRACT_BITS;
			after_cblack = read_data_muxed - cblack;
			after_mult = (after_cblack_clipped * wb_mult);
			pixel_fixed = after_mult >> FRACT_BITS;			
		end
        
     always_comb
        case(position)
            2'b00: read_data_muxed = pixel_in[63:48];
            2'b01: read_data_muxed = pixel_in[47:32];
            2'b10: read_data_muxed = pixel_in[47:32];
            2'b11: read_data_muxed = pixel_in[31:16];  
        endcase

 
        assign after_cblack_clipped = after_cblack[16] ? 0 : after_cblack[15:0];
        assign pixel_fixed_clipped = (| pixel_fixed[31-FRACT_BITS : 16]) ? 16'hffff : pixel_fixed[15:0]; 	
endmodule


module demosaic_wb
(   input logic clk,
    input logic reset,
    input logic[15:0] FWIDTH,
    input logic[15:0] FHEIGHT,
    input logic[15:0] crop_width,
    input logic[15:0] crop_height,
    input logic[63:0] read_data,
    input logic[15:0] wb_mult,
    input logic[15:0] cblack,
    output logic data_v,
    output logic[15:0] red,green,blue,
    output logic[31:0] adr,
    output logic done);

    logic[15:0] wb_read_data;
    logic[1:0] position;

    demosaic u_demosaic(clk, reset, FWIDTH, FHEIGHT, crop_width, crop_height, wb_read_data, data_v, red, green, blue, adr, position, done);
    
    white_balancing u_white_balancing(clk, reset, position, read_data, wb_mult, cblack, wb_read_data);

endmodule
