//TOP for multi device + new 10bit ADC 

module TOP_202512TO(

	input CLK,
	input ORDER,

	input POR,
    input [1:0] unique_low,
    input unique_debug,

//manchester decoder
    input MAN,
    input DECODER_RST,
    output CLK_OUT,
    output ORDER_OUT,


//electric stimulation
	output P_STIM_EN,
	output N_STIM_EN,
	
	output [4:0] P_STIM,
	output [4:0] N_STIM,

//optical stimulation

	output	[4:0] OPT_STIM,

// electric measuring
	input	COMPARATOR_ELE,
	output	S_Bias_ELE,
	output	COMP_CLK_ELE,
	output	S1_ELE,
	output	[9:0]	S2_ELE,//DATA_ELE,
	output	S2_dummy_ELE,
	output	S3_ELE,
    output  [4:0] CAL1_ELE,CAL2_ELE,

	
// optical measuring
	input	COMPARATOR_OPT,
	output	S_Bias_OPT,
	output	COMP_CLK_OPT,
	output	S1_OPT,
	output	[9:0]	S2_OPT,//DATA_OPT,
	output	S2_dummy_OPT,
	output	S3_OPT,
    output  [4:0] CAL1_OPT,CAL2_OPT,

// convolutional encoding debug
	input conv_encoder_state,        // デバッグ用: CONV_ENCODERの動作モード切替
    input [3:0] DEBUG_DATA_LOWER,    // デバッグモード用の下位4bit入力（外部パッド）
    input S_Bias_ELE_IN,             // COM_CON_OUTへのS_Bias_ELE入力（外部パッド）
    input S_Bias_OPT_IN,             // COM_CON_OUTへのS_Bias_OPT入力（外部パッド）
    input ENCODE_ENABLE_ext,    // 外部パッドからのENCODE_ENABLE入力

//communication control
    output  SERIAL_OUT,

//communication control SAKATA version
    output  SERIAL_OUT_SAKATA

);


//address
wire [7:0] unique;
assign unique[7:6] = 2'b00;
assign unique[5:2] = unique_debug ? 4'b1111 : 4'b0000;
assign unique[1:0] = unique_low[1:0];

localparam general = 8'b1111_1111;

//manchester decoder
MAN_DECODER MAN_DECODER(
.MAN(MAN),
.POR(POR),
.RST(DECODER_RST),
.DATA_OUT(ORDER_OUT),
.CLK_OUT(CLK_OUT)
);

//command
wire [399:0] command;
COMMAND COMMAND(
.ADDRESS(unique),
.general(general),
.CLK(CLK),
.POR(POR),
.IN(ORDER),
.COMMAND(command)
);


//electric stimulation
wire [4:0]	stim_n;
wire [4:0]   stim_p;

STIM ELE_P_STIM(
.CLK(CLK),
.POR(POR),
.RST(1'b0),
.PERIOD({command[37:30],command[27:20]}),
.WIDTH({command[57:50],command[47:40]}), 
.LOOP({command[77:70],command[67:60]}),
.DELAY({command[97:90],command[87:80]}),
.INTENSITY(command[104:100]),
.OPERATE(command[105] & command[14] & command[10]),
.STIM(stim_p)
); 

STIM ELE_N_STIM(
.CLK(CLK),
.POR(POR),
.RST(1'b0),
.PERIOD({command[127:120],command[117:110]}),
.WIDTH({command[147:140],command[137:130]}), 
.LOOP({command[167:160],command[157:150]}),
.DELAY({command[187:180],command[177:170]}),
.INTENSITY(command[194:190]),
.OPERATE(command[195] & command[14] & command[10]),
.STIM(stim_n)
);

ELE_STIM_XOR ELE_STIM_XOR(
.CLK(CLK),
.POR(POR),
.P_STIM(stim_p),
.N_STIM(stim_n),
.P_STIM_XOR(P_STIM),
.N_STIM_XOR(N_STIM),
.P_STIM_EN_XOR(P_STIM_EN),
.N_STIM_EN_XOR(N_STIM_EN)
);

//optical stimulation
STIM   OPTICAL_STIM(
.CLK(CLK),
.POR(POR),
.RST(1'b0),
.PERIOD({command[247:240],command[237:230]}),
.WIDTH({command[267:260],command[257:250]}), 
.LOOP({command[287:280],command[277:270]}),
.DELAY({command[307:300],command[297:290]}),
.INTENSITY(command[314:310]),
.OPERATE(command[16] & command[10]),
.STIM(OPT_STIM)
);

//electric measuring
wire 	[9:0]	DATA_ELE;
MEASURE	ELECTRIC_MEAS(
.CLK(CLK),
.POR(POR),
.RST(1'b0),
.DELAY({command[217:210],command[207:200]}),
.OPERATE(command[15] & command[10]),
.COMPARATOR(COMPARATOR_ELE),
.S_Bias(S_Bias_ELE),
.COMP_CLK(COMP_CLK_ELE),
.S1(S1_ELE),
.DATA(DATA_ELE),
.S2(S2_ELE),
.S2_dummy(S2_dummy_ELE),
.S3(S3_ELE),
.CAL1(CAL1_ELE),
.CAL2(CAL2_ELE)
);



//optical measuring
wire  [9:0]  DATA_OPT;
MEASURE	OPTICAL_MEAS(
.CLK(CLK),
.POR(POR),
.RST(1'b0),
.DELAY({command[337:330],command[327:320]}),
.OPERATE(command[17] & command[10]),
.COMPARATOR(COMPARATOR_OPT),
.S_Bias(S_Bias_OPT),
.COMP_CLK(COMP_CLK_OPT),
.S1(S1_OPT),
.DATA(DATA_OPT),
.S2(S2_OPT),
.S2_dummy(S2_dummy_OPT),
.S3(S3_OPT),
.CAL1(CAL1_OPT),
.CAL2(CAL2_OPT)
);


//communication control
COM_CON_OUT COM_CON_OUT(
.CLK(CLK),
.POR(POR),
.S_Bias_OPT(S_Bias_OPT_IN),
.S_Bias_ELE(S_Bias_ELE_IN),
.OPERATE_OPT(command[17]),
.OPERATE_ELE(command[15]),
.DATA_OPT(DATA_OPT[9:0]),
.DATA_ELE(DATA_ELE[9:0]),
.ADDRESS(unique[7:0]),
.ENCODE_ENABLE(command[343] | ENCODE_ENABLE_ext), // 内部コマンドOR外部入力
.conv_encoder_state(conv_encoder_state), // デバッグ用モード切替
.DEBUG_DATA_LOWER(DEBUG_DATA_LOWER),  // デバッグ用下位4bit
.OUT(SERIAL_OUT)
);

//communication control SAKATA version
wire COM_EN_OPT_SAKATA, COM_EN_ELE_SAKATA;
COM_CON_OUT_SAKATA COM_CON_OUT_SAKATA(
.CLK(CLK),
.POR(POR),
.S_Bias_OPT(S_Bias_OPT_IN),
.S_Bias_ELE(S_Bias_ELE_IN),
.OPERATE_OPT(command[17]),
.OPERATE_ELE(command[15]),
.DATA_OPT(DATA_OPT[9:0]),
.DATA_ELE(DATA_ELE[9:0]),
.ADDRESS(unique[7:0]),
.COM_EN_OPT(COM_EN_OPT_SAKATA),
.COM_EN_ELE(COM_EN_ELE_SAKATA),
.OUT(SERIAL_OUT_SAKATA)
);

endmodule 
