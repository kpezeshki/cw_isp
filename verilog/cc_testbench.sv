////////////////////////////////////////////////////////////////
// cc_testbench.sv
// Christine Goins  cgoins@hmc.edu  3/31/18
// testbench for colorspace_conversion.sv

module cc_testbench();
	
	logic clk, reset, data_ready, data_valid;
	logic [15:0] pixel_in_red, pixel_in_green, pixel_in_blue;
	logic [15:0] pixel_out_red, pixel_out_green, pixel_out_blue;
	logic signed [8:0][11:0] cc_coeff;
	
	initial clk = 0;
	always #5 clk = ~clk;
	
	colorspace_conversion #(16, 6, 6) cc(clk, reset, data_ready, pixel_in_red, pixel_in_green, pixel_in_blue, cc_coeff, data_valid, pixel_out_red, pixel_out_green, pixel_out_blue);
	
	initial begin
		reset = 1;
		#5 reset=0;
		
		data_ready=1;
	
//		cc_coeff = {28'd98, -28'd61, 28'd15,
//						28'd2, 28'd161, -28'd97,
//						-28'd21, -28'd61, 28'd262};

		cc_coeff = {12'd124, -12'd71, 12'd11,
						-12'd14, 12'd105, -12'd28,
						12'd1, -12'd33, 12'd96};
	
		pixel_in_red = 1;
		pixel_in_green = 35;
		pixel_in_blue = 65535;

		#10;
		
		data_ready=0;
		
		#20;
		
	end

endmodule
