////////////////////////////////////////////////////////////////
// colorspace_conversion.sv
// Christine Goins  cgoins@hmc.edu  3/23/18
// colorspace_conversion converts pixels from the camera colorspace to the desired colorspace

module colorspace_conversion #(parameter PIXEL_WIDTH=16,
										 parameter FRAC_BITS=6,
										 parameter INT_BITS=6)
										(input logic clk,
										 input logic reset,
										 input logic data_ready,
										 input logic  [PIXEL_WIDTH-1:0] pixel_in_red,
										 input logic [PIXEL_WIDTH-1:0] pixel_in_green,
										 input logic [PIXEL_WIDTH-1:0] pixel_in_blue,
										 input logic signed [8:0][INT_BITS+FRAC_BITS-1:0] cc_coeff,
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
	flopenr #(PIXEL_WIDTH) red_flop(clk, reset, data_ready, pixel_calc[0], pixel_out_red);
	flopenr #(PIXEL_WIDTH) green_flop(clk, reset, data_ready, pixel_calc[1], pixel_out_green);
	flopenr #(PIXEL_WIDTH) blue_flop(clk, reset, data_ready, pixel_calc[2], pixel_out_blue);
	
endmodule 


// signed fixed point matrix multiplier
module matrix_mult #(parameter PIXEL_WIDTH=16,
							parameter FRAC_BITS=6,
							parameter INT_BITS=6)
						  (input logic [2:0][PIXEL_WIDTH-1:0] in,
							input logic signed [8:0][INT_BITS+FRAC_BITS-1:0] matrix,
							output logic [2:0][PIXEL_WIDTH-1:0] out);
	
	// make input signed
	logic signed [2:0][PIXEL_WIDTH:0] signed_in;
	// fixed point output
	logic signed [2:0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:0] fp_out, fp_out_pos;
	// for checking if output is greater than 2^PIXEL_WIDTH
	logic [2:0] too_big;
	
	// for testing
	logic signed [PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:0] r_a, r_b, r_c, g_a, g_b, g_c, b_a, b_b, b_c;
	// red
	assign r_a = signed_in[2]*matrix[2];
	assign r_b = signed_in[1]*matrix[1];
	assign r_c = signed_in[0]*matrix[0];
	// green
	assign g_a = signed_in[2]*matrix[5];
	assign g_b = signed_in[1]*matrix[4];
	assign g_c = signed_in[0]*matrix[3];
	// blue
	assign b_a = signed_in[2]*matrix[8];
	assign b_b = signed_in[1]*matrix[7];
	assign b_c = signed_in[0]*matrix[6];

	
	//assign signed_in = in;
	assign signed_in[2] = in[2];
	assign signed_in[1] = in[1];
	assign signed_in[0] = in[0];
	
	// matrix mutliplication and rounding
	assign fp_out[2] = signed_in[2]*matrix[8] + signed_in[1]*matrix[7] + signed_in[0]*matrix[6] + 2**(FRAC_BITS-1);
	assign fp_out[1] = signed_in[2]*matrix[5] + signed_in[1]*matrix[4] + signed_in[0]*matrix[3] + 2**(FRAC_BITS-1);
	assign fp_out[0] = signed_in[2]*matrix[2] + signed_in[1]*matrix[1] + signed_in[0]*matrix[0] + 2**(FRAC_BITS-1);
	
	// clipping result of fixed point matrix multiplication to be in range [0,65535]
	// assign to 0 if negative
	assign fp_out_pos[0] = (fp_out[0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1]) ? 0 : fp_out[0];
	assign fp_out_pos[1] = (fp_out[1][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1]) ? 0 : fp_out[1];
	assign fp_out_pos[2] = (fp_out[2][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1]) ? 0 : fp_out[2];
	
	// assign to 65535 if greater than 65535
	assign too_big[0] = | fp_out_pos[0][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:PIXEL_WIDTH+FRAC_BITS];
	assign too_big[1] = | fp_out_pos[1][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:PIXEL_WIDTH+FRAC_BITS];
	assign too_big[2] = | fp_out_pos[2][PIXEL_WIDTH+FRAC_BITS+INT_BITS-1:PIXEL_WIDTH+FRAC_BITS];
	
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
		if 	  (reset) 	d <= 0;
		else if (en)	d <= q;

endmodule

// D Flip-flop with asynchronous reset
module flopr #(parameter DATA_WIDTH=1)
			 (input logic clk,
			  input logic reset,
			  input logic [DATA_WIDTH-1:0] q,
			  output logic [DATA_WIDTH-1:0] d);

	always_ff@(posedge clk, posedge reset)
		if (reset)	d <= 0;
		else		d <= q;

endmodule
