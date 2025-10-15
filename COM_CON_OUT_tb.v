`timescale 1ns/1ns

module COM_CON_OUT_tb;
reg CLK, POR, S_Bias_OPT,S_Bias_ELE;
wire OPERATE_OPT,OPERATE_ELE;
wire [7:0] ADDRESS;
wire [11:0] DATA_OPT,DATA_ELE;
wire OUT;
wire COM_EN_OPT, COM_EN_ELE;


assign OPERATE_OPT = 1'b1;
assign OPERATE_ELE = 1'b1;
assign ADDRESS [7:0] = 8'b1111_0011;
assign DATA_OPT[11:0] = 10'b0110_0101_11;
assign DATA_ELE[11:0] = 10'b1001_1010_00;

COM_CON_OUT COM_CON_OUT(
.CLK(CLK),.POR(POR),.S_Bias_OPT(S_Bias_OPT),.S_Bias_ELE(S_Bias_ELE),
.COM_EN_OPT(COM_EN_OPT),.COM_EN_ELE(COM_EN_ELE),
.OPERATE_OPT(OPERATE_OPT),.OPERATE_ELE(OPERATE_ELE),
.ADDRESS(ADDRESS[7:0]),.DATA_OPT(DATA_OPT[11:0]),.DATA_ELE(DATA_ELE[11:0]),.OUT(OUT)
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

initial fork
         S_Bias_OPT = 1'b0;
#100000  S_Bias_OPT = 1'b1;
#180000  S_Bias_OPT = 1'b0;
#920000  S_Bias_OPT = 1'b1;
#1000000 S_Bias_OPT = 1'b0;
#1920000 S_Bias_OPT = 1'b1;
join

initial fork
         S_Bias_ELE = 1'b0;
#100000  S_Bias_ELE = 1'b1;
#180000  S_Bias_ELE = 1'b0;
#920000  S_Bias_ELE = 1'b1;
#1000000 S_Bias_ELE = 1'b0;
#1920000 S_Bias_ELE = 1'b1;
join

initial begin
    $dumpfile("COM_CON_OUT_tb.vcd");
    $dumpvars(0, COM_CON_OUT_tb);
    // テストの内容
    #2000000;  // 適切な時間待つ
    $finish;  // シミュレーション終了
end

endmodule
