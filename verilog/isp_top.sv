module inter_reg #(parameter WIDTH = 8)
                  (input  logic             clk,reset,enable,
                   input  logic [WIDTH-1:0] d,
                   output logic [WIDTH-1:0] q);
    
    always_ff @(posedge clk, posedge reset)
        if (reset)        q <= 0;
        else if (enable)  q <= d;
endmodule

module control(input  logic        clk, reset, new_frame, data_valid, read_data,
               input  logic [31:0] init_write_address,
               output logic [31:0] write_address,
               output logic        write_enable, crop_enable, wb_enable, cc_enable
               );
    
    assign cc_enable = data_valid;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            write_enable <= 0;
            crop_enable <= 0;
            wb_enable <= 0;
            write_address <= init_write_address;
        end

        else begin
            crop_enable  <= crop_enable  | read_data;
            wb_enable    <= wb_enable    | crop_enable;
            write_enable <= write_enable | data_valid;

            write_address <= write_address + write_enable;
        end
    end
endmodule

module isp_top #(parameter PIXEL_WIDTH = 16,
             parameter FRAC_BITS_CC = 6,
             parameter INT_BITS_CC = 6,
             parameter FRAC_BITS_WB = 8)
           (input logic clk, reset, new_frame,
           //configuration
           input logic [31:0] init_write_address,
           input logic [9:0]  top_margin, left_margin,
           input logic [15:0] crop_height, crop_width,
           input logic [15:0] color_scale, cblack,
           input logic [INT_BITS_CC+FRAC_BITS_CC+PIXEL_WIDTH-1:0] color_conv,
           input logic [63:0] read_data,
           //memory interface
           output logic write_enable,
           output logic [31:0] write_address, read_address,
           output logic [63:0] write_data
           );

           //control signals
           logic data_valid, crop_enable, wb_enable, cc_enable;

           //inter-module data signals
           logic [15:0] cropped_pixel, wb_pixel;
           logic [15:0] demos_pixel[3:0];
           logic [15:0] cc_pixel[3:0];

           //combinational logic
           assign write_data = {cc_pixel[0], cc_pixel[1], cc_pixel[2], 16'b0};

           //module instantiation
           control control_isp (
               .clk        (clk),
               .reset      (reset),
               //control inputs
               .new_frame  (new_frame),
               .data_valid (data_valid),
               .read_data  (read_data),
               //configuration inputs
               .init_write_address (init_write_address),
               //outputs
               .write_address (write_address),
               .write_enable  (write_enable),
               .crop_enable   (crop_enable),
               .wb_enable     (wb_enable),
               .cc_enable     (cc_enable)
           );

           colorspace_conversion 
           #(.PIXEL_WIDTH (PIXEL_WIDTH),
             .FRAC_BITS   (FRAC_BITS_CC),
             .INT_BITS    (INT_BITS_CC)
           )
           cc_conv (
               .clk      (clk),
               .reset    (reset),
               //control signals
               .data_ready (cc_enable),
               //input pixel
               .pixel_in_red   (demos_pixel[0]),
               .pixel_in_green (demos_pixel[1]),
               .pixel_in_blue  (demos_pixel[2]),
               //configuration
               .cc_coeff (color_conv),
               //output pixel
               .pixel_out_red   (cc_pixel[0]),
               .pixel_out_green (cc_pixel[1]),
               .pixel_out_blue  (cc_pixel[2])
           );

           white_balancing 
           #(.FRACT_BITS (FRAC_BITS_WB))
           wb_en (
               .clk (clk),
               .reset (reset),
               //configuration data
               .wb_mult (color_scale),
               .cblack  (cblack),
               //input image
               .pixel_in (read_data[15:0]),
               //output image
               .pixel_out (wb_pixel)
           );

           demosaic demos_isp
           (
               .clk   (clk),
               .reset (reset),
               //configuration data
               .FWIDTH  (crop_width),
               .FHEIGHT (crop_height),
               //input data
               .read_data ({48'b0, wb_pixel}),
               //output data
               .data_v (data_valid),
               .red    (demos_pixel[0]),
               .green  (demos_pixel[1]),
               .blue   (demos_pixel[2]),
               .adr    (read_address)
           );

endmodule

module demosaic #()
(   input logic clk,
    input logic reset,
    input logic[15:0] FWIDTH,
    input logic[15:0] FHEIGHT,
    //input logic[7:0] BITS_PER_RAW,
    //input logic[7:0] BAYER,
    input logic[63:0] read_data,
    output logic data_v,
    output logic[15:0] red,green,blue,
    output logic[31:0] adr,
    //output logic mem_write,
    output logic done);

    logic[4000:0][63:0] linebuf1, linebuf2, linebuf3;
    logic[2:0][63:0] top3, mid3, bot3;
    logic [15:0] row_read, col_read;
    logic [15:0] col_shift, row_calc, col_calc;
    logic end_of_row;
    logic next1, next2, next3;

    // round-robin, row_read, col_read logic
    always_ff@(posedge clk)
        if (reset) begin
            row_read <= 0;
            col_read <= 0;
            next1 <= 0;
            next2 <= 0;
            next3 <= 1;
        end
        else if (col_read != FWIDTH-1) col_read <= col_read + 1;
        else if ((row_read == 0) || end_of_row) begin
            row_read <= row_read + 1;
            col_read <= 0;
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

    // line buffer logic
    always_ff@(posedge clk)
        if (row_read < FHEIGHT) begin
            if (next1) linebuf1[col_read] <= read_data;
            else if (next2) linebuf2[col_read] <= read_data;
            else if (next3) linebuf3[col_read] <= read_data;
        end
        else begin
            if (next1) linebuf1[col_read] <= 0;
            else if (next2) linebuf2[col_read] <= 0;
            else if (next3) linebuf3[col_read] <= 0;
        end

    assign adr = 32'h10000 + row_read*FWIDTH + col_read;

    // col_shift logic
    always_ff@(posedge clk)
        if (reset || end_of_row) col_shift <= 0;
        else if (col_read != 0 && col_shift != FWIDTH) col_shift <= col_shift + 1;

    // 3-pixel buffer logic
    always_ff@(posedge clk)
        if (reset || end_of_row) begin
            top3[2:1] <= 0;
            mid3[2:1] <= 0;
            bot3[2:1] <= 0;
        end
        else begin
            top3[2:1] <= top3[1:0];
            mid3[2:1] <= mid3[1:0];
            bot3[2:1] <= bot3[1:0];
        end
    always_ff@(posedge clk)
        if (reset || (col_shift == FWIDTH) || end_of_row) begin
            top3[0] <= 0;
            mid3[0] <= 0;
            bot3[0] <= 0;
        end
        else begin
            if (next1) begin
                top3[0] <= linebuf2[col_shift];
                mid3[0] <= linebuf3[col_shift];
                bot3[0] <= linebuf1[col_shift];
            end
            else if (next2) begin
                top3[0] <= linebuf3[col_shift];
                mid3[0] <= linebuf1[col_shift];
                bot3[0] <= linebuf2[col_shift];
            end
            else if (next3) begin
                top3[0] <= linebuf1[col_shift];
                mid3[0] <= linebuf2[col_shift];
                bot3[0] <= linebuf3[col_shift];
            end
        end

    // col_calc, row_calc logic
    always_ff@(posedge clk)
        if (reset) begin
            row_calc <= 0;
            col_calc <= 0;
        end
        else if (end_of_row) begin
            row_calc <= row_calc + 1;
            col_calc <= 0;
        end
        else if (row_read != 0 && col_shift != 0 && col_shift != 1) begin
            col_calc <= col_calc + 1;
        end

    assign end_of_row = (col_calc == FWIDTH - 1);
    assign position = {row_calc[0],col_calc[0]};

    logic green_multi, red_multi, blue_multi;
    // Neighbor averaging logic    
    always_comb
        case(position)
            2'b00:
                begin
                    red = mid3[1];
                    green = (mid3[0]+mid3[2]+top3[1]+bot3[1]) * green_multi;
                    blue = (top3[0]+top3[2]+bot3[0]+bot3[2]) * blue_multi;
                end
            2'b01:
                begin
                    red = (mid3[0]+mid3[2]) * red_multi;
                    green = mid3[1];
                    blue = (top3[1]+bot3[1]) * blue_multi;
                end
            2'b10:
                begin
                    red = (top3[1]+bot3[1]) * red_multi;
                    green = mid3[1];
                    blue = (mid3[0]+mid3[2]) * blue_multi;
                end
            2'b11:
                begin
                    red = (top3[0]+top3[2]+bot3[0]+bot3[2]) * red_multi;
                    green = (mid3[0]+mid3[2]+top3[1]+bot3[1]) * green_multi;
                    blue = mid3[1];
                end
        endcase

    // Multipliers. NEEDS TO BE FIXED
    // red_multi
    always_comb
        case(position)
            2'b00:
                red_multi = 1;
            2'b01:
                if (col_calc == FWIDTH - 1) red_multi = 1;
                else red_multi = 0.5;
            2'b10:
                if (row_calc == FHEIGHT - 1) red_multi = 1;
                else red_multi = 0.5;
            2'b11:
                if (row_calc == FHEIGHT - 1 && col_calc == FWIDTH - 1) red_multi = 1;
                else if (row_calc == FHEIGHT - 1 || col_calc == FWIDTH - 1) red_multi = 0.5;
                else red_multi = 0.25;
        endcase

    // green_multi
    always_comb
        case(position)
            2'b00:
                if (row_calc == 0 && col_calc == 0) green_multi = 0.5;
                else if (row_calc == 0 || col_calc == 0) green_multi = 1/3;
                else green_multi = 0.25;
            2'b01:
                green_multi = 1;
            2'b10:
                green_multi = 1;
            2'b11:
                if (row_calc == FHEIGHT - 1 && col_calc == FWIDTH - 1) green_multi = 0.5;
                else if (row_calc == FHEIGHT - 1 || col_calc == FWIDTH - 1) green_multi = 1/3;
                else green_multi = 0.25;
        endcase
 
    // blue_multi
    always_comb
        case(position)
            2'b00:
                if (row_calc == 0 && col_calc == 0) blue_multi = 1;
                else if (row_calc == 0 || col_calc == 0) blue_multi = 0.5;
                else blue_multi = 0.25;
            2'b01:
                if (row_calc == 0) blue_multi = 1;
                else blue_multi = 0.5;
            2'b10:
                if (col_calc == 0) blue_multi = 1;
                else blue_multi = 0.5;
            2'b11:
                blue_multi = 1;
        endcase
 
    logic row_cal;

    assign data_v = (row_read != 0) && (col_shift != 0) && (col_shift != 1);
    assign done = (row_cal == FHEIGHT - 1) && end_of_row;

endmodule

module white_balancing #(parameter FRACT_BITS = 8)
							 (input  logic clk, reset,
							  input  logic [15:0] pixel_in,
							  input  logic [15:0] wb_mult,
							  input  logic [15:0] cblack,
							  output logic [15:0] pixel_out);
	
	logic [23:0] after_mult;
	logic [15:0] after_cblack;
	logic [15:0] pixel_fixed;

	always_ff @(posedge clk, posedge reset)
		if (reset) 	pixel_out <= 0;
		else 			pixel_out <= pixel_fixed;
		
	always_comb
		begin
			//fixed_mult = wb_mult << FRACT_BITS;
			after_cblack = pixel_in - cblack;
			after_mult = (after_cblack * wb_mult);
			pixel_fixed = after_mult >> FRACT_BITS;			
		end
	
endmodule

module colorspace_conversion #(parameter PIXEL_WIDTH=16,
                                         parameter FRAC_BITS=6,
                                         parameter INT_BITS=6)
                                        (input logic clk,
                                         input logic reset,
                                         input logic data_ready,
                                         input logic  [PIXEL_WIDTH-1:0] pixel_in_red,
                                         input logic [PIXEL_WIDTH-1:0] pixel_in_green,
                                         input logic [PIXEL_WIDTH-1:0] pixel_in_blue,
                                         input logic signed [8:0][INT_BITS+FRAC_BITS+PIXEL_WIDTH-1:0] cc_coeff,
                                         output logic data_valid,
                                         output logic [PIXEL_WIDTH-1:0] pixel_out_red,
                                         output logic [PIXEL_WIDTH-1:0] pixel_out_green,
                                         output logic [PIXEL_WIDTH-1:0] pixel_out_blue);
    
    // result of matrix multiplication rounded
    logic [2:0][PIXEL_WIDTH-1:0] pixel_calc;
    
    // data ready/valid
    flopr #(1) ready_valid(clk, reset, data_ready, data_valid);
    // matrix multiplier                                     
    matrix_mult #(PIXEL_WIDTH, FRAC_BITS, INT_BITS) multiplier({pixel_in_red, pixel_in_green, pixel_in_blue}, cc_coeff, pixel_calc);
    
    // registers to store output of multiplication
    flopenr #(PIXEL_WIDTH) red_flop(clk, reset, data_valid, pixel_calc[0], pixel_out_red);
    flopenr #(PIXEL_WIDTH) green_flop(clk, reset, data_valid, pixel_calc[1], pixel_out_green);
    flopenr #(PIXEL_WIDTH) blue_flop(clk, reset, data_valid, pixel_calc[2], pixel_out_blue);
    
endmodule 
// signed fixed point matrix multiplier
module matrix_mult #(parameter PIXEL_WIDTH=16,
                            parameter FRAC_BITS=6,
                            parameter INT_BITS=6)
                          (input logic [2:0][PIXEL_WIDTH-1:0] in,
                            input logic signed [8:0][INT_BITS+FRAC_BITS+PIXEL_WIDTH-1:0] matrix,
                            output logic [2:0][PIXEL_WIDTH-1:0] out);
    
    // make input signed
    logic signed [2:0][PIXEL_WIDTH:0] signed_in;
    // fixed point output
    logic signed [2:0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:0] fp_out, fp_out_pos;
    // for checking if output is greater than 2^PIXEL_WIDTH
    logic [2:0] too_big;
    
    // for testing
    logic signed [PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:0] out_a, out_b, out_c;
    assign out_a = signed_in[2]*matrix[2];
    assign out_b = signed_in[1]*matrix[1];
    assign out_c = signed_in[0]*matrix[0];
    
    
    //assign signed_in = in;
    assign signed_in[2] = in[2];
    assign signed_in[1] = in[1];
    assign signed_in[0] = in[0];
    
    // matrix mutliplication
    assign fp_out[2] = signed_in[2]*matrix[8] + signed_in[1]*matrix[7] + signed_in[0]*matrix[6];
    assign fp_out[1] = signed_in[2]*matrix[5] + signed_in[1]*matrix[4] + signed_in[0]*matrix[3];
    assign fp_out[0] = signed_in[2]*matrix[2] + signed_in[1]*matrix[1] + signed_in[0]*matrix[0];
    
    
    // rounding result of fixed point matrix multiplication
    // assign to 0 if negative
    assign fp_out_pos[0] = (fp_out[0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1]) ? 0 : fp_out[0];
    assign fp_out_pos[1] = (fp_out[1][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1]) ? 0 : fp_out[1];
    assign fp_out_pos[2] = (fp_out[2][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1]) ? 0 : fp_out[2];
    
    // assign to 65535 if greater than 65535
    assign too_big[0] = fp_out_pos[0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-2] | fp_out_pos[0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-3] | fp_out_pos[0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-4];
    assign too_big[1] = fp_out_pos[1][PIXEL_WIDTH+FRAC_BITS+INT_BITS-2] | fp_out_pos[1][PIXEL_WIDTH+FRAC_BITS+INT_BITS-3] | fp_out_pos[1][PIXEL_WIDTH+FRAC_BITS+INT_BITS-4];
    assign too_big[2] = fp_out_pos[2][PIXEL_WIDTH+FRAC_BITS+INT_BITS-2] | fp_out_pos[2][PIXEL_WIDTH+FRAC_BITS+INT_BITS-3] | fp_out_pos[2][PIXEL_WIDTH+FRAC_BITS+INT_BITS-4];
    
    assign out[0] = (too_big[0]) ? (2**PIXEL_WIDTH)-1 : fp_out_pos[0][PIXEL_WIDTH+FRAC_BITS-1:FRAC_BITS];
    assign out[1] = (too_big[1]) ? (2**PIXEL_WIDTH)-1 : fp_out_pos[1][PIXEL_WIDTH+FRAC_BITS-1:FRAC_BITS];
    assign out[2] = (too_big[2]) ? (2**PIXEL_WIDTH)-1 : fp_out_pos[2][PIXEL_WIDTH+FRAC_BITS-1:FRAC_BITS];
    
endmodule
// D Flip-flop with enable and asynchronous reset
module flopenr #(parameter DATA_WIDTH=16)
              (input logic clk,
               input logic reset,
                input logic en,
               input logic [DATA_WIDTH-1:0] q,
               output logic [DATA_WIDTH-1:0] d);
    always_ff@(posedge clk, posedge reset)
        if    (reset)   d <= 0;
        else if (en)    d <= q;
endmodule
// D Flip-flop with asynchronous reset
module flopr #(parameter DATA_WIDTH=1)
             (input logic clk,
              input logic reset,
              input logic [DATA_WIDTH-1:0] q,
              output logic [DATA_WIDTH-1:0] d);
    always_ff@(posedge clk, posedge reset)
        if (reset)  d <= 0;
        else        d <= 1;
endmodule









    