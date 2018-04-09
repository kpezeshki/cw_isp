module test_top();
    // To compare output binary file with expected
    // use xxd b1.bin > b1.hex | xxd b2.bin > b2.hex | diff b1.hex b2.hex

    logic clk,reset;
    logic [63:0] read_data,write_data;
    logic [31:0] adr;
    logic done,cc_data_valid;

    logic [63:0] ram[0:2**28-1];
    logic [15:0] red,green,blue;
    logic [15:0] fwidth, fheight, crop_width, crop_height;  
    logic [15:0] wb_mult,cblack;
    logic signed [8:0][11:0] cc_coeff;

    assign fwidth= 5218;
    assign fheight = 3482;
    assign crop_width = 126;
    assign crop_height = 100;
    
    assign wb_mult = 16'h04e4; //16'h05ae for Canon camera images, 16'h04e4 for test image
    assign cblack = 2048;    
    assign cc_coeff = {12'd124, -12'd71, 12'd11,
			-12'd14, 12'd105, -12'd28,
			12'd1, -12'd33, 12'd96};

    top dut(clk, reset, fwidth, fheight, crop_width, crop_height, read_data, wb_mult, cblack, cc_coeff, adr, cc_data_valid, red, green, blue, done); // Instantiate DUT

    always begin
        #5; clk = ~clk; // Generate clock
    end

    assign read_data = ram[adr];    // Memory

    int file_in, file_out;
    initial begin
        clk = 0;
        file_in = $fopen("before.bin","rb");
        $fread(ram[0],file_in,32'h10000); // Read image into ram
        $fclose(file_in);
        file_out = $fopen("test_top_out.txt","w");
        reset = 1; #27; reset = 0;
    end
    int j,k;
    always_ff @(negedge clk)
        if (cc_data_valid) begin
            $fwrite(file_out,"%x_",red);
            $fwrite(file_out,"%x_",green);
            $fwrite(file_out,"%x_",blue);
            $fwrite(file_out,"%4x\n",0);
        end

    always_ff @(negedge clk)
        if (done) begin
            $display("Test Finished");
            $fclose(file_out);
            $finish;
        end
endmodule
