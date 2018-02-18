module isp_top(input  logic        clk, reset,
               input  logic [11:0] x_size, y_size,
               input  logic [15:0] subpixel,
               output logic [48:0] pixel_out,
               output logic        data_ready);
    

    logic enable_cs; // high when value ready for color scaling
    logic enable_cc; // high when value ready for colorspace conversion
    logic enable_out // high when value ready for output register
    
    logic [2:0] regs[47:0]; //intermediate value registers

    logic enable_cs;     //high when there is a pixel for 


module inter_reg #(parameter WIDTH = 8)
                  (input  logic             clk,reset,enable
                   input  logic [WIDTH-1:0] d.
                   output logic [WIDTH-1:0] q);
    
    always_ff @(posedge clk, posedge reset)
        if (reset)    q <= 0;
        else if (en)  q <= d;
endmodule

module enable_calc(input logic clk, reset
                   input logic scanline_full, en_cs, en_cc
                   output logic in_cs_out, en_cc_out, en_out);
        
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            en_cs_out <= 0;
            en_cc_out <= 0;
            en_out    <= 0;
        end

        else begin
            if (scanline_full) en_cs_out <= 1;
            else if (en_cs)    en_cc_out <= 1;
            else if (en_cc)    en_out    <= 1;
        end
    end
endmodule



    