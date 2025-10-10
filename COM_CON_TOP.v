//COM_CON_TOP for multi device + new 10bit ADC + convolutional encoding

module COM_CON_TOP (
    input CLK, POR, S_Bias_OPT, S_Bias_ELE,
    input [1:0] OPERATE, TYPE,
    input [7:0] ADDRESS,
    input [19:0] DATA,
    input ENCODE_ENABLE,           // 符号化ON/OFFフラグ（command[343]から）
    output OUT, ENABLE
);

// ADC_STATE synchronization
reg ADC_STATE;

always @(posedge CLK or negedge POR) begin
    if (!POR)
        ADC_STATE <= 1'b0;
    else
        ADC_STATE <= S_Bias_OPT || S_Bias_ELE;
end

wire C_OUT1, S_OUT, S_ADDRESS, CLK5;
wire [2:0] state_comcon;

// 符号化関連の信号
wire [31:0] encoder_input;
wire [63:0] encoder_output;
wire encoder_start;
wire encode_done;
wire [63:0] output_data;

// 符号化入力データの準備（ADDRESS, TYPE, DATA + 終端2bit）
assign encoder_input = {ADDRESS[7:0], TYPE[1:0], DATA[19:0], 2'b00};

// 符号化開始信号（counter状態でENCODE_ENABLEがアクティブな時）
// stateがcounterの時にencoderがstartになる。
// ENCODE_ENABLEは外部信号
assign encoder_start = (state_comcon == 3'b001) && ENCODE_ENABLE;

// 畳み込み符号化器
CONV_ENCODER CONV_ENCODER(
    .CLK(CLK),
    .POR(POR),
    .START(encoder_start),
    .DATA_IN(encoder_input),
    .DATA_OUT(encoder_output),
    .ENCODE_DONE(encode_done)
);

// データセレクタ（符号化ON/OFFでデータを選択）
// 符号化OFF時: DATAの20bitのみ（ADDRESSとTYPEはSELECT.vで別途シリアル化）
assign output_data = ENCODE_ENABLE ? encoder_output : {44'b0, DATA[19:0]};

COM_ENABLE COM_ENABLE(
.CLK(CLK),.POR(POR),
.ADC_STATE(ADC_STATE),
.DELAY(ADDRESS[5:0]),
.OPERATE(OPERATE),
.CLK5(CLK5),
.ENABLE(ENABLE)
);


COUNTER_COMCON COUNTER_COMCON(
.CLK(CLK),
.CLK5(CLK5),
.POR(POR),
.ADC_STATE(ADC_STATE),
.state(state_comcon),
.C_OUT1(C_OUT1)
);

// 確認済み
SHIFT_REG SHIFT_REG(
.CLK(CLK),
.CLK5(CLK5),
.POR(POR),
.ADC_STATE(ADC_STATE),
.ENABLE(ENABLE),
.state(state_comcon),
.DATA(output_data),                 // 64bitデータ（符号化ON/OFFで選択済み）
.ENCODE_ENABLE(ENCODE_ENABLE),
.ENCODE_DONE(encode_done),
.S_OUT(S_OUT)
);

// state
// 確認済み
SELECT SELECT(
.CLK(CLK),
.CLK5(CLK5),
.POR(POR),
.ADC_STATE(ADC_STATE),
.ENABLE(ENABLE),
.state(state_comcon),
.TYPE(TYPE),
.C_OUT1(C_OUT1),
.S_OUT(S_OUT),
.OUT(OUT),
.ADDRESS(ADDRESS[7:0]),
.ENCODE_ENABLE(ENCODE_ENABLE),
);

endmodule
