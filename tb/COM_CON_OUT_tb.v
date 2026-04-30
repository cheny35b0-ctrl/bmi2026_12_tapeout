`timescale 1ns/1ns

module COM_CON_OUT_tb;
reg CLK, POR;
reg S_Bias_OPT, S_Bias_ELE;  // 注: TOPモジュールではMEASUREモジュールから生成される
wire OPERATE_OPT,OPERATE_ELE;
reg [7:0] ADDRESS;
wire [9:0] DATA_OPT,DATA_ELE;
reg ENCODE_ENABLE;           // 注: TOPモジュールではcommand[343] | ENCODE_ENABLE_ext
reg conv_encoder_state;      // デバッグ用モード切替信号
wire OUT;


assign OPERATE_OPT = 1'b1;  // 注: TOPモジュールではcommand[17] | OPERATE_OPT_ext
assign OPERATE_ELE = 1'b1;  // 注: TOPモジュールではcommand[15] | OPERATE_ELE_ext
assign DATA_OPT[9:0] = 10'b1110_0101_11;
assign DATA_ELE[9:0] = 10'b1001_1010_10;

COM_CON_OUT COM_CON_OUT(
.CLK(CLK),.POR(POR),.S_Bias_OPT(S_Bias_OPT),.S_Bias_ELE(S_Bias_ELE),
.OPERATE_OPT(OPERATE_OPT),.OPERATE_ELE(OPERATE_ELE),
.ADDRESS(ADDRESS[7:0]),.DATA_OPT(DATA_OPT[9:0]),.DATA_ELE(DATA_ELE[9:0]),
.ENCODE_ENABLE(ENCODE_ENABLE),
.conv_encoder_state(conv_encoder_state),
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

// S_Bias_OPT制御 (TOPモジュールではMEASUREモジュールから生成)
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

// S_Bias_ELE制御 (TOPモジュールではMEASUREモジュールから生成)
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

initial begin
    ADDRESS = 8'b0000_0000;
end

initial fork
         ADDRESS = 8'b0000_0000;
#950000  ADDRESS = 8'b0010_0101;
#1950000 ADDRESS = 8'b0010_1110;
join

// ENCODE_ENABLE制御 (TOPモジュールではcommand[343] | ENCODE_ENABLE_extで決定)
initial fork
         ENCODE_ENABLE = 1'b0;      // 最初は符号化OFF
#950000  ENCODE_ENABLE = 1'b1;      // 1回目の測定は符号化ON
#1950000 ENCODE_ENABLE = 1'b0;      // 2回目の測定は符号化OFF
#2950000 ENCODE_ENABLE = 1'b1;      // 3回目の測定は符号化ON
join

// conv_encoder_state制御 (通常モード/デバッグモード切り替え)
initial fork
         conv_encoder_state = 1'b0; // 最初は通常モード
#950000  conv_encoder_state = 1'b0; // 1回目の測定は通常モード
#1950000 conv_encoder_state = 1'b1; // 2回目の測定はデバッグモード
#2950000 conv_encoder_state = 1'b1; // 3回目の測定はデバッグモード
join

// デバッグモード時のテストデータはCOM_CON_OUT内のlocalparamで設定 (DEBUG_TEST_DATA = 20'h7B3A9)

initial begin
    $dumpfile("COM_CON_OUT_tb.vcd");
    $dumpvars(0, COM_CON_OUT_tb);
    // テストの内容
    #4000000;  // 適切な時間待つ
    $finish;  // シミュレーション終了
end

endmodule
