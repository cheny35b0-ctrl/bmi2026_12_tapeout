//STIM for multi device + new 10bit ADC


module STIM(
	input	CLK,POR,RST,
	input	[15:0] DELAY,WIDTH,PERIOD,LOOP,
	input	[4:0]  INTENSITY, 
	input	OPERATE,
	output	reg	[4:0]	STIM	


	);



localparam none = 2'b00, delay = 2'b10, on = 2'b11 , fin = 2'b01;

wire [15:0] msec_count;

counter_16bit MSEC( .CLK(CLK), .POR(POR), .RST(RST), .COUNT_UP(OPERATE), .PERIOD(16'd10000), .COUNT(msec_count) );

reg	[1:0]	state;	

wire	[15:0]	delaycnt;
wire	[15:0]	periodcnt;
wire	[15:0]	loopcnt;

always @( posedge CLK or negedge POR)begin
	if(!POR)
		state <= none;
	else if( RST )
		state <= none;
	else if (( PERIOD < WIDTH) || (WIDTH == 16'h0000) || (LOOP == 16'h0000) || (PERIOD == 16'h0000) )
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
			if((OPERATE == 1'b1)&&(loopcnt +1'b1 > LOOP) )
				state <= fin; 
			else
				state <= on;
		fin:
			if(OPERATE == 1'b0)
				state <= none; 
			else
				state <= fin;
		default:
				state <= none;
		endcase
end


counter_16bit delay_counter( .CLK(CLK), .POR(POR), .RST((RST)||(state != delay) ), .COUNT_UP( (state == delay) && (msec_count == 16'd9999)),
							 .PERIOD(16'hFFFF), .COUNT(delaycnt) );

counter_16bit period_counter( .CLK(CLK), .POR(POR), .RST((RST)||(state != on)), .COUNT_UP( (state == on)    && (msec_count == 16'd9999)), 
							.PERIOD(PERIOD), .COUNT(periodcnt) );

counter_16bit loop_counter( .CLK(CLK), .POR(POR), .RST((RST)||(state != on)), .COUNT_UP( (state == on) && (msec_count == 16'd9999) && (periodcnt + 1'b1  == WIDTH)),
							.PERIOD(16'hFFFF), .COUNT(loopcnt) );



always @( posedge CLK  or negedge POR)begin
	if(!POR)
		STIM <= 5'b00000;
	else if( RST )
		STIM <= 5'b00000;
	else if ( (state == on)&&(periodcnt < WIDTH) )
		STIM <= INTENSITY;
	else
		STIM <= 5'b00000;
end

endmodule