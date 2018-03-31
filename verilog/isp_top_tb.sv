////////////////////////////////////////////////////////////////
// isp_top_tb.sv
// Christine Goins  cgoins@hmc.edu  3/31/18
// testbench for isp_top.sv

module isp_top_tb();

	logic clk, reset, new_frame;
	logic [31:0] init_write_addr, write_addr, read_addr;
	logic [9:0] top_margin, left_margin;
	logic [15:0] crop_height, crop_width;
	logic [15:0] color_scale, cblack;
	logic [INT_BITS_CC+FRAC_BITS_CC+PIXEL_WIDTH-1:0];
	logic [63:0] read_data, write_data;
	
	// RAM
	logic [63:0] ram[0:2**18-1]; // change this size

	int image_in, image_out;

	isp_top #(.PIXEL_WIDTH(16), .FRAC_BITS_CC(6), .INT_BITS_CC(6), .FRAC_BITS_WB(8))
	dut     (.clk						(clk),
				.reset					(reset),
				.new_frame				(new_frame),
				// configuration
				.init_write_address	(init_write_addr), // change name
				.top_margin				(top_margin)
				.left_margin			(left_margin),
				.crop_height			(crop_height),
				.crop_width				(crop_width),
				.color_scale			(color_scale),
				.cblack					(cblack),
				.cc_coeff				(cc_coeff),
				// memory interface
				.read_data				(read_data),
				.write_enable			(write_enable),
				.write_address			(write_addr),
				.read_address			(read_addr),
				.write_data				(write_data)
				);
	
	
	// assign variables
	assign init_write_addr = 32'h20000;
	assign top_margin = 10'd100;
	assign left_margin = 10'd126;
	assign crop_height = 16'd3482;
	assign crop_width = 16'd5218;
	assign color_scale = ;
	assign cblack = ;
	assign cc_coeff =	{28'd124, -28'd71, 28'd11,
							-28'd14, 28'd105, -28'd28,
							28'd1, -28'd33, 28'd96};
	
	// generate clk
	always begin
		#5; clk = ~clk;
	end
	
	// RAM
	assign read_data = ram[read_addr];
	always_ff @(posedge clk)
		if (mem_write) 	ram[write_addr] <= write_data;
		

	initial begin
		clk = 0;
		
		// load image from file
		image_in = $fopen("raw_image.bin", "rb");
		// load image into RAM
		$fread(ram[0], image_in,32'h10000);
		$fclose(image_in);
		
		reset = 1; #17; reset = 0;
		
		new_frame = 1; #7; new_frame = 0;
	end
	
	
	always_ff @(negedge clk)
		// how to know when it's done?
		image_out = $fopen("test_image.bin", "w");
		
		for (i=32'h20000; i<(32'h20000+FWIDTH+FHEIGHT); j=j+1) begin
			for (k=0; k<8; k++) begin
				$fwrite(image_out, "%c", ram[i][63-8*k-:8]);
			end
		end
		
		$display("Test Finished);
		$fclose(image_out);
		$finish;
		
		
	//end


endmodule
