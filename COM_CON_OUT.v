//COM_CON_OUT for multi device + new 10bit ADC + convolutional encoding

module COM_CON_OUT(
   input CLK,POR,S_Bias_OPT,S_Bias_ELE,OPERATE_OPT,OPERATE_ELE,
   input [9:0] DATA_OPT,DATA_ELE,
   input [7:0] ADDRESS,
   input ENCODE_ENABLE,              // 符号化ON/OFFフラグ（command[343]から）
   input conv_encoder_state,         // デバッグ用: 1でデバッグモード、0で通常モード
   input [3:0] DEBUG_DATA_LOWER,     // デバッグモード用の下位4bit入力（外部パッドから）
   output OUT
);

// デバッグモード用の上位ビット固定値（下位4bitを除く16bit分）
localparam [15:0] DEBUG_DATA_UPPER = 16'hAAAA;

wire [1:0] MEASUREMENT_CODE;
wire [19:0] DATA;

// conv_encoder_stateに応じてDATA出力を切り替え
// Low: 通常モード（DATA_OPTとDATA_ELEを連結）
// High: デバッグモード（上位16bitを固定値、下位4bitは外部入力）
assign DATA = conv_encoder_state ? {DEBUG_DATA_UPPER, DEBUG_DATA_LOWER} : {DATA_OPT, DATA_ELE};


COM_CON_TOP COM_CON_TOP(
.CLK(CLK),
.POR(POR),
.S_Bias_OPT(S_Bias_OPT),
.S_Bias_ELE(S_Bias_ELE),
.DATA(DATA),
.OPERATE(MEASUREMENT_CODE),
.TYPE(MEASUREMENT_CODE),
.ADDRESS(ADDRESS[7:0]),
.ENCODE_ENABLE(ENCODE_ENABLE),
.OUT(OUT)
);

MEASUREMENT_TYPE_ENCODER MEASUREMENT_TYPE_ENCODER(
.CLK(CLK),
.POR(POR),
.OPERATE_OPT(OPERATE_OPT),
.OPERATE_ELE(OPERATE_ELE),
.OUT(MEASUREMENT_CODE)
);

endmodule
