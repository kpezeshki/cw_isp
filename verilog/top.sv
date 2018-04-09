module top #(parameter PIXEL_WIDTH=16,
             parameter FRAC_BITS=6,
             parameter INT_BITS=6) 
(   input logic clk,
    input logic reset,
    input logic[15:0] FWIDTH,
    input logic[15:0] FHEIGHT,
    input logic[15:0] crop_width,
    input logic[15:0] crop_height,
    input logic[63:0] read_data,
    input logic[15:0] wb_mult,
    input logic[15:0] cblack,
    input logic signed [8:0][INT_BITS + FRAC_BITS-1:0] cc_coeff,
    output logic[31:0] adr,
    output logic data_v,
    output logic [PIXEL_WIDTH-1:0] red,
    output logic [PIXEL_WIDTH-1:0] green,
    output logic [PIXEL_WIDTH-1:0] blue,
    output logic done);


    logic int_data_v, demosaic_done;
    logic[15:0] int_red, int_green, int_blue;

    demosaic_wb u_demosaic_wb(clk, reset, FWIDTH, FHEIGHT, crop_width, crop_height, read_data, wb_mult, cblack, int_data_v, int_red, int_green, int_blue, adr, demosaic_done);

    colorspace_conversion u_cc (clk, reset, int_data_v, int_red, int_green, int_blue, cc_coeff, demosaic_done, data_v, blue, green, red, done);

endmodule
