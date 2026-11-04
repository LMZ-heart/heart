`timescale 1ns / 1ps

module qrs_detect #(
    parameter SAMPLING_RATE = 500,
    parameter THRESHOLD    = 12'd2000,
    parameter MAX_INTERVAL = 19'd1000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] data_in,
    input  wire        data_valid,
    output reg  [7:0]  heart_rate,
    output reg         qrs_pulse
);

reg [11:0] data_prev;
reg [18:0] cnt_interval;
reg        peak_flag;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_prev <= 0; cnt_interval <= 0; heart_rate <= 8'd60; qrs_pulse <= 1'b0; peak_flag <= 1'b0;
    end
    else begin
        qrs_pulse <= 1'b0;
        if(data_valid) begin
            data_prev <= data_in;
            cnt_interval <= cnt_interval + 1'b1;

            if((data_in > THRESHOLD) && (data_in > data_prev) && (!peak_flag)) begin
                peak_flag <= 1'b1;
            end
            else if((data_in < THRESHOLD) && peak_flag) begin
                peak_flag    <= 1'b0;
                qrs_pulse    <= 1'b1;
                if(cnt_interval > 0) heart_rate <= (8'd60 * SAMPLING_RATE) / cnt_interval[15:0];
                cnt_interval <= 0;
            end

            if(cnt_interval > MAX_INTERVAL) begin
                cnt_interval <= 0; heart_rate <= 8'd0;
            end
        end
    end
end

endmodule
