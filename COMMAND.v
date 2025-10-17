//Verilog HDL for "BMI18_digital", "COMMAND" "functional"


module COMMAND(
	input	[7:0] ADDRESS,general,
	input	CLK,POR,
	input   IN,
	output  reg [399:0]     COMMAND
);

wire	[3:0]	start,stop;

counter_4bit START( .CLK(CLK), .POR(POR),.RST((IN == 1'b0)), .COUNT_UP((IN == 1'b1)),
				 .PERIOD(4'hF), .COUNT(start));
counter_4bit STOP ( .CLK(CLK), .POR(POR),.RST((IN == 1'b1)), .COUNT_UP((IN == 1'b0)),
				 .PERIOD(4'hF), .COUNT(stop));

localparam write = 1'b1, standby = 1'b0;

reg state;//
wire [15:0] com;//

always @(posedge CLK or negedge POR) begin//listen
	if (!POR)
		state <= standby;
	else
		case(state)
		write:
			if((stop >= 4'd10)&&(IN == 1'b1))
				state <= standby;
			else if ((com >= 16'd8 ) && (COMMAND[7:0] != ADDRESS) && (COMMAND[7:0] != general))
				state <= standby;
			else if ((com >= 16'd10 ) && (COMMAND[10]==1))
				state <= standby;
			else
				state <= write;
		standby:
			if((start >= 4'd10)&&(IN == 1'b0))
				state <= write;
			else
				state <= standby;
		default:
				state <= standby;
		endcase
end

counter_16bit COM( .CLK(CLK), .POR(POR),.RST((state != write)), .COUNT_UP((state == write)),
				 .PERIOD(16'hFFFF), .COUNT(com) );



always @( posedge CLK or negedge POR) begin//comandcom
	if(!POR)
		COMMAND[399:0] <= {400{1'b0}};
	else if ( state == write )
		COMMAND[com] <= IN;
	else
		COMMAND <= COMMAND;
end



endmodule
