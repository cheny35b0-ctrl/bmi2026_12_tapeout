`timescale 1ns/1ns

module COM_CON_OUT_SAKATA_tb;
reg CLK, POR;
reg S_Bias_OPT, S_Bias_ELE;
reg OPERATE_OPT, OPERATE_ELE;
reg [7:0] ADDRESS;
reg [9:0] DATA_OPT, DATA_ELE;
wire COM_EN_OPT, COM_EN_ELE;
wire OUT;

COM_CON_OUT_SAKATA COM_CON_OUT_SAKATA(
.CLK(CLK),
.POR(POR),
.S_Bias_OPT(S_Bias_OPT),
.S_Bias_ELE(S_Bias_ELE),
.OPERATE_OPT(OPERATE_OPT),
.OPERATE_ELE(OPERATE_ELE),
.DATA_OPT(DATA_OPT[9:0]),
.DATA_ELE(DATA_ELE[9:0]),
.ADDRESS(ADDRESS[7:0]),
.COM_EN_OPT(COM_EN_OPT),
.COM_EN_ELE(COM_EN_ELE),
.OUT(OUT)
);

//CLOCK generation//
always begin
     CLK = 1'b1;
#50 CLK = 1'b0;
#50;
end

initial fork
          POR = 1'b0;
#300   POR = 1'b1;
join

// OPERATE信号制御
initial fork
         OPERATE_OPT = 1'b0;
#500     OPERATE_OPT = 1'b1;
join

initial fork
         OPERATE_ELE = 1'b0;
#500     OPERATE_ELE = 1'b1;
join

// S_Bias_OPT制御
initial fork
         S_Bias_OPT = 1'b0;
#100000  S_Bias_OPT = 1'b1;
#180000  S_Bias_OPT = 1'b0;
#950000  S_Bias_OPT = 1'b1;
#1000000 S_Bias_OPT = 1'b0;
#1950000 S_Bias_OPT = 1'b1;
#2000000 S_Bias_OPT = 1'b0;
#2950000 S_Bias_OPT = 1'b1;
#3000000 S_Bias_OPT = 1'b0;
join

// S_Bias_ELE制御
initial fork
         S_Bias_ELE = 1'b0;
#100000  S_Bias_ELE = 1'b1;
#180000  S_Bias_ELE = 1'b0;
#950000  S_Bias_ELE = 1'b1;
#1000000 S_Bias_ELE = 1'b0;
#1950000 S_Bias_ELE = 1'b1;
#2000000 S_Bias_ELE = 1'b0;
#2950000 S_Bias_ELE = 1'b1;
#3000000 S_Bias_ELE = 1'b0;
join

// DATA制御
initial fork
         DATA_OPT = 10'b1110_0101_11;
         DATA_ELE = 10'b1001_1010_10;
join

// ADDRESS制御
initial fork
         ADDRESS = 8'b0000_0000;
#950000  ADDRESS = 8'b0010_0101;
#1950000 ADDRESS = 8'b0010_1110;
join

initial begin
    $dumpfile("COM_CON_OUT_SAKATA_tb.vcd");
    $dumpvars(0, COM_CON_OUT_SAKATA_tb);
    #4000000;  // 適切な時間待つ
    $finish;  // シミュレーション終了
end

endmodule
