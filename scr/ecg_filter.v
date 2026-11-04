`timescale 1ns / 1ps

module ecg_filter #(
    parameter DATA_W = 12,
    parameter AVG_LEN = 16
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [DATA_W-1:0]    adc_in,
    input  wire                 adc_valid,
    output reg  [DATA_W-1:0]    data_out,
    output reg                  data_valid
);

localparam SUM_W = DATA_W + 5;
reg [DATA_W-1:0] shift_reg [0:AVG_LEN-1];
reg [SUM_W-1:0]  sum;
reg [3:0]        ptr;
reg              fill_done;
wire [SUM_W-1:0] sum_next;
wire [DATA_W-1:0] avg_out;

assign sum_next = fill_done ? (sum - shift_reg[ptr] + adc_in) : (sum + adc_in);
assign avg_out  = sum_next[SUM_W-1:4];

integer i;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sum <= 0; ptr <= 0; data_out <= 0; data_valid <= 1'b0; fill_done <= 1'b0;
        for (i=0; i<AVG_LEN; i=i+1) shift_reg[i] <= 0;
    end else begin
        data_valid <= 1'b0;
        if(adc_valid) begin
            sum <= sum_next;
            shift_reg[ptr] <= adc_in;
            ptr <= ptr + 1'b1;
            if(ptr == AVG_LEN - 1) fill_done <= 1'b1;
            data_out   <= avg_out;
            data_valid <= 1'b1;
        end
    end
end

endmodule
