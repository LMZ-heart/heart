`timescale 1ns / 1ps

module xadc_top(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vauxp11_in, // 通道11正极
    input  wire        vauxn11_in, // 通道11负极
    output wire        uart_txd
);

// 100MHz 二分频产生 50MHz 给 XADC
reg clk_50m;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) clk_50m <= 1'b0;
    else       clk_50m <= ~clk_50m;
end

wire [11:0] adc_data_raw;
wire        adc_valid_raw;
wire [11:0] adc_data_ds;
wire        adc_valid_ds;

wire [15:0] xadc_do_out;
wire        xadc_drdy;
reg [6:0]   daddr_in;
reg         den_in;

// XADC 例化 (DRP 模式，通道11)
xadc_wiz_0 xadc_inst (
    .dclk_in     (clk_50m),
    .reset_in    (~rst_n),
    .vauxp11     (vauxp11_in),
    .vauxn11     (vauxn11_in),
    .daddr_in    (daddr_in),
    .den_in      (den_in),
    .dwe_in      (1'b0),
    .di_in       (16'd0),
    .drdy_out    (xadc_drdy),
    .do_out      (xadc_do_out),
    .vp_in       (1'b0), .vn_in (1'b0), .channel_out (), .eoc_out (),
    .alarm_out   (), .eos_out (), .busy_out ()
);

// DRP 读取控制逻辑 (通道11的地址是 7'h1B)
always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n) begin
        daddr_in <= 7'h1B;
        den_in <= 1'b0;
    end
    else begin
        daddr_in <= 7'h1B;
        den_in <= 1'b1;
    end
end

assign adc_data_raw  = xadc_do_out[15:4];
assign adc_valid_raw = xadc_drdy;

// 降采样 (100MHz -> 500Hz)
reg [17:0] ds_cnt;
reg [11:0] ds_data_reg;
reg        ds_valid_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin ds_cnt <= 0; ds_data_reg <= 0; ds_valid_reg <= 1'b0; end
    else begin
        ds_valid_reg <= 1'b0;
        if(adc_valid_raw) begin
            if(ds_cnt >= 18'd199999) begin
                ds_cnt <= 0; ds_data_reg <= adc_data_raw; ds_valid_reg <= 1'b1;
            end else ds_cnt <= ds_cnt + 1'b1;
        end
    end
end
assign adc_data_ds  = ds_data_reg;
assign adc_valid_ds = ds_valid_reg;

// 滤波与心率
wire [11:0] filter_data_out;
wire        filter_data_valid;
ecg_filter filter_inst (
    .clk(clk), .rst_n(rst_n), .adc_in(adc_data_ds), .adc_valid(adc_valid_ds),
    .data_out(filter_data_out), .data_valid(filter_data_valid)
);

wire [7:0] heart_rate;
wire       qrs_pulse;
qrs_detect #(.SAMPLING_RATE(500)) qrs_inst (
    .clk(clk), .rst_n(rst_n), .data_in(filter_data_out), .data_valid(filter_data_valid),
    .heart_rate(heart_rate), .qrs_pulse(qrs_pulse)
);

// ==========================================================
// 串口发送 (FireWater 字符串协议 VOFA+使用)
// ==========================================================
reg [7:0]  tx_data;
reg        tx_en;
reg [3:0]  tx_state;
wire       tx_busy;

wire [7:0] adc_val = filter_data_out[11:4];

wire [3:0] hr_10 = heart_rate / 10;
wire [3:0] hr_1  = heart_rate % 10;
wire [3:0] adc_100 = adc_val / 100;
wire [3:0] adc_10  = (adc_val % 100) / 10;
wire [3:0] adc_1   = adc_val % 10;

reg filter_valid_d1;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) filter_valid_d1 <= 1'b0;
    else       filter_valid_d1 <= filter_data_valid;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tx_state <= 0; tx_en <= 0; tx_data <= 0;
    end else begin
        tx_en <= 1'b0;
        if(tx_state == 0) begin
            if(filter_valid_d1) tx_state <= 1;
        end else if(!tx_busy && !tx_en) begin
            tx_en <= 1'b1;
            case(tx_state)
                1: begin tx_data <= 8'h30 + hr_10; tx_state <= 2; end
                2: begin tx_data <= 8'h30 + hr_1;  tx_state <= 3; end
                3: begin tx_data <= 8'h2C;         tx_state <= 4; end
                4: begin tx_data <= 8'h30 + adc_100; tx_state <= 5; end
                5: begin tx_data <= 8'h30 + adc_10;  tx_state <= 6; end
                6: begin tx_data <= 8'h30 + adc_1;   tx_state <= 7; end
                7: begin tx_data <= 8'h0A;           tx_state <= 0; end
                default: tx_state <= 0;
            endcase
        end
    end
end

uart_tx uart_inst (
    .clk(clk), .rst_n(rst_n), .tx_data(tx_data), .tx_en(tx_en), .txd(uart_txd), .tx_busy(tx_busy)
);

endmodule
