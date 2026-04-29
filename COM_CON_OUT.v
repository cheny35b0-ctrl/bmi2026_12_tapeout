//COM_CON_OUT for multi device + new 10bit ADC + convolutional encoding

module COM_CON_OUT(
   input CLK,POR,S_Bias_OPT,S_Bias_ELE,OPERATE_OPT,OPERATE_ELE,
   input [9:0] DATA_OPT,DATA_ELE,
   input [7:0] ADDRESS,
   input ENCODE_ENABLE,              // 符号化ON/OFFフラグ（command[343]から）
   input conv_encoder_state,         // デバッグ用: 1でデバッグモード、0で通常モード
   output OUT
);

// デバッグモード用のテストデータ（20bit固定値）
localparam [19:0] DEBUG_TEST_DATA = 20'h7B3A9;

wire [1:0] MEASUREMENT_CODE;
wire [19:0] DATA;

// conv_encoder_stateに応じてDATA出力を切り替え
// Low: 通常モード（DATA_OPTとDATA_ELEを連結）
// High: デバッグモード（固定テストデータ）
assign DATA = conv_encoder_state ? DEBUG_TEST_DATA : {DATA_OPT, DATA_ELE};


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
