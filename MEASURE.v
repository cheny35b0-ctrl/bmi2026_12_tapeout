//MEASURE for multi device + new 10bit ADC
module MEASURE(
//for MEASURE
	input	       POR,
	input	       RST,
	input	       CLK,
	input	[15:0] DELAY, 
	input	       OPERATE,

//for ADC_logic 10bit
	input	COMPARATOR,
	output	S_Bias,
	output	COMP_CLK,
	output	S1,
	output	[9:0]	DATA,
	output	[9:0]	S2,
	output	S2_dummy,
	output	S3,
    output  [4:0] CAL1,CAL2
	);

localparam none = 2'b00, delay = 2'b10, on = 2'b11 ;
reg	[1:0]	state;	
wire	[15:0]	delaycnt;	
wire	[15:0]	msec_count;
wire adc_start = (state == on) && (msec_count == 16'd0001);

counter_16bit MSEC(
.CLK(CLK),
.POR(POR),
.RST(RST),
.COUNT_UP(OPERATE),
.PERIOD(16'd10000),
.COUNT(msec_count)
);


always  @(posedge CLK or negedge POR)begin
	if(!POR)
		state <= none;
	else if(RST)
		state <= none;
	else
		case(state)
		none:
			if((OPERATE == 1'b1)&&(DELAY == 16'h0000) )
				state <= on;
			else if((OPERATE == 1'b1)&&(delaycnt < DELAY) )
				state <= delay; 
			else
				state <= none;
		delay:
			if((OPERATE == 1'b1)&&(delaycnt >= DELAY) )
				state <= on; 
			else
				state <= delay;
		on:
			if(OPERATE == 1'b0)
				state <= none; 
			else
				state <= on;
		default:
				state <= none;
		endcase
end

counter_16bit delay_counter(
.CLK(CLK),
.POR(POR),
.RST((RST)||(state != delay)),
.COUNT_UP( (state == delay) && (msec_count == 16'd9999)),
.PERIOD(16'hFFFF),
.COUNT(delaycnt)
);
 
ADC_logic ADC_logic(
.CLK(CLK),
.POR(POR),
.RST((RST)||(state != on)),
.START(adc_start),
.COMPARATOR(COMPARATOR),
.S_Bias(S_Bias),
.COMP_CLK(COMP_CLK),
.DATA(DATA),
.S1(S1),
.S2(S2),
.S2_dummy(S2_dummy),
.S3(S3),
.OFF_CAL1(CAL1),
.OFF_CAL2(CAL2)
);

endmodule
