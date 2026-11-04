`timescale 1ns / 1ps

module uart_tx(
    input  wire       clk,       // 100MHz
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_en,
    output reg        txd,
    output wire       tx_busy
);

localparam BAUD_CNT = 868; // 115200波特率 @ 100MHz

reg [15:0] baud_cnt;
reg [3:0]  bit_cnt;
reg        busy;
reg [9:0]  tx_shift;

assign tx_busy = busy;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        txd <= 1'b1; busy <= 1'b0; baud_cnt <= 0; bit_cnt <= 0; tx_shift <= 10'h3FF;
    end else begin
        if(tx_en && !busy) begin
            busy <= 1'b1;
            tx_shift <= {1'b1, tx_data, 1'b0}; // 停止位, 数据8位, 起始位
            baud_cnt <= 0;
            bit_cnt <= 0;
            txd <= 1'b0;
        end else if(busy) begin
            if(baud_cnt == BAUD_CNT - 1) begin
                baud_cnt <= 0;
                if(bit_cnt == 9) begin
                    busy <= 1'b0;
                    txd <= 1'b1;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                    txd <= tx_shift[bit_cnt + 1];
                end
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end
    end
end

endmodule
