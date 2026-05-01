module ADC_logic ( 
	input		 CLK,POR,RST,
	input		 START,
	input		 COMPARATOR,
	output	reg  S_Bias,
	output	reg  COMP_CLK,
	output	reg	 S1,S2_dummy,S3,
	output	reg	 [9:0] DATA,
	output	reg	 [9:0] S2,
    output       [4:0] OFF_CAL1,OFF_CAL2
);

localparam none = 2'b00, on = 2'b11;

reg [1:0] state;
reg CALIB_ON,C_SIDE;
wire[7:0] phase;
wire[7:0] count_COMP_CLK;

//state
always  @(posedge CLK or negedge POR )begin
	if(!POR)
		state <= none;
	else if(RST)
		state <= none;
	else
		case(state)
		none:
			if (START == 1'b1)	//If START changes to H, start measurement.
				state <= on;
			else
				state <= none;
		on:
			if (phase == 8'd31)	
				state <= none;
			else
				state <= on;
		default:
				state <= none;
		endcase
end

//count_COMP_CLK 
counter_8bit counter_5us(
.CLK(CLK),
.POR(POR),
.RST((RST)||(state == none)),
.COUNT_UP((state == on)),
.PERIOD(8'd15),
.COUNT(count_COMP_CLK)
);

//count "phase"
counter_8bit counter_phase(
.CLK(CLK),
.POR(POR),
.RST((RST)||(state == none)),
.COUNT_UP((count_COMP_CLK == 8'd1)),
.PERIOD(8'hFF),
.COUNT(phase)
);

//generate "COMP_CLK"
always @(posedge CLK or negedge POR) begin
	if (!POR)
		COMP_CLK <= 1'b0;
	else if(RST)
		COMP_CLK <= 1'b0;
	else if((state == on)&&(phase >= 8'd3))
	    if((count_COMP_CLK >= 8'd12)&&(count_COMP_CLK <= 8'd15))
	        COMP_CLK <= 1'b0;
       	else
	      	COMP_CLK <= 1'b1;
    else
      COMP_CLK <= 1'b0;
end


//generate "DATA"
always @(posedge CLK or negedge POR) begin
	if (!POR)
		DATA <= 10'b00_0000_0000;
	else if(RST)
		DATA <= 10'b00_0000_0000;
	else if ((state == on)&&( count_COMP_CLK == 8'd14)&&( phase >= 8'd4 )&&( phase <= 8'd13 ) )
		DATA[8'd13 - phase] <= COMPARATOR;
	else
		DATA <= DATA;
end

//generate "CALIB_ON" which is enable signal for offset calibration
always @(posedge CLK or negedge POR)  begin
    if(!POR)
     CALIB_ON <= 1'b0;
    else if(RST)
     CALIB_ON <= 1'b0;
    else if ((state == on)&&(phase >= 8'd18)&&(phase <= 8'd25))
     CALIB_ON <= 1'b1;
    else
     CALIB_ON <= 1'b0;
end

//generate "C_SIDE" which is side selection signal for offset calibration
always @(posedge CLK or negedge POR)  begin
    if(!POR)
     C_SIDE <= 1'b0;
    else if(RST)
     C_SIDE <= 1'b0;
    else if ((state == on)&&(phase == 8'd19)&&(count_COMP_CLK == 8'd14))
        if(COMPARATOR)
          C_SIDE <= 1'b1;
        else
          C_SIDE <= 1'b0;
    else
     C_SIDE <= C_SIDE;
end

//generate "S_Bias, S1, S2_dummy, S3",signals
always @(posedge CLK or negedge POR)  begin
	if (!POR)
		{S_Bias, S1, S2_dummy, S3} <= 4'b0011;
	else if (RST)
		{S_Bias, S1, S2_dummy, S3} <= 4'b0011;
    else if( ( state == on)&&(phase <= 8'd1))
        {S_Bias, S1, S2_dummy, S3} <= 4'b1011;
    else if( ( state == on)&&(phase >= 8'd14))
        {S_Bias, S1, S2_dummy, S3} <= 4'b1111;
	else if( state == on)
		case ( phase )
            8'd0   :  {S_Bias, S1, S2_dummy, S3} <= 4'b1011;
            8'd1   :  {S_Bias, S1, S2_dummy, S3} <= 4'b1011; //sampling start
		    8'd2   :  {S_Bias, S1, S2_dummy, S3} <= 4'b1010; //sampling finish
			default:  {S_Bias, S1, S2_dummy, S3} <= 4'b1100;
		endcase
	else
		 {S_Bias, S1, S2_dummy, S3} <= 4'b0011;
end


//generate "S2<11:0>",signals that depends on input voltage
always @(posedge CLK or negedge POR)  begin
	if (!POR)
		S2 <= 10'b11_1111_1111;
    else if(RST)
        S2 <= 10'b11_1111_1111;
    else if(state == none)
        S2 <= 10'b11_1111_1111;
    else if ((state == on)&&(phase>= 8'd15)&&(phase<= 8'd25))
        S2 <= DATA[9:0];
    else if ((state == on)&&(phase == 8'd26))
        S2 <= {2'b11,DATA[7:0]};
    else if ((state == on)&&(phase == 8'd27))
        S2 <= {4'b1111,DATA[5:0]};
    else if ((state == on)&&(phase == 8'd28))
        S2 <= {6'b111111,DATA[3:0]};
    else if ((state == on)&&(phase == 8'd29))
        S2 <= {8'b11111111,DATA[1:0]};
    else if ((state == on)&&(phase == 8'd30))
        S2 <= 10'b11_1111_1111;
	else if ( state == on)
		case ( phase )
            8'd3 :  S2 <= 10'b00_0000_0000;
			8'd4 :	S2 <= { 1'b1, {9{1'b0}} };
			8'd5 :	S2 <= {DATA[9],    1'b1, { 8{1'b0}} };
			8'd6 :	S2 <= {DATA[9:8],  1'b1, { 7{1'b0}} };
			8'd7 :	S2 <= {DATA[9:7],  1'b1, { 6{1'b0}} };
			8'd8 :	S2 <= {DATA[9:6],  1'b1, { 5{1'b0}} };
			8'd9 :	S2 <= {DATA[9:5],  1'b1, { 4{1'b0}} };
			8'd10 :	S2 <= {DATA[9:4],  1'b1, { 3{1'b0}} };
			8'd11:	S2 <= {DATA[9:3],  1'b1, { 2{1'b0}} };
			8'd12:	S2 <= {DATA[9:2],  1'b1, 1'b0};
			8'd13:	S2 <= {DATA[9:1],  1'b1};
             8'd14:	S2 <=  DATA[9:0];
			default:S2 <= 10'b11_1111_1111;
		endcase
	else
	S2 <= 10'b11_1111_1111;
end

offset_calib offset_calib(
.CLK(CLK),
.POR(POR),
.RST(RST),
.CALIB_ON(CALIB_ON),
.count_COMP_CLK(count_COMP_CLK),
.COMPARATOR(COMPARATOR),
.state(state),
.SW1(OFF_CAL1),
.SW2(OFF_CAL2),
.C_SIDE(C_SIDE)
);

endmodule