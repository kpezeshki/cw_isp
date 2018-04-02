module isp_control_testbench();
 logic clk, reset;
 logic new_frame, data_valid, read_data, write_enable, wb_enable, cc_enable;
 logic [31:0] frame_buffer_base_adr;
 logic [31:0] write_address;
 logic [34:0] expected;
 logic [31:0] vectornum, errors;
 logic [69:0] testvectors[10000:0];

// instantiate device under test
control dut(
    clk, reset, new_frame, data_valid, read_data, 
    frame_buffer_base_adr, write_address, write_address, 
    wb_enable, cc_enable);

// generate clock
always
 begin
 clk=1; #5; clk=0; #5;
 end

// at start of test, load vectors
// and pulse reset
initial
 begin
 $readmemb("control_testvectors.tv", testvectors);
 vectornum = 0; errors = 0; reset = 1; #22; reset = 0;
 end

// apply test vectors on rising edge of clk
always @(posedge clk)
 begin
 #1; {new_frame, data_valid, read_data, frame_buffer_base_adr, expected} = testvectors[vectornum];
 end

// check results on falling edge of clk
always @(negedge clk)
 if (~reset) begin // skip during reset
 if ({write_address, write_enable, wb_enable, cc_enable} !== expected) begin // check result
 $display("Error: inputs = %b %b %b %b", {new_frame, data_valid, read_data, frame_buffer_base_adr});
 $display(" outputs = %b %b %b %b (%b expected)",
 write_address, write_enable, wb_enable, cc_enable, expected);
 errors = errors + 1;
 end
 vectornum = vectornum + 1;
 if (testvectors[vectornum] === 70'bx) begin
 $display("%d tests completed with %d errors", vectornum,
errors);
 $stop;
 end
 end
endmodule