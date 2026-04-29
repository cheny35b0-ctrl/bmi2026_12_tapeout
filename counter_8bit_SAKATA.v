//counter_8bit_SAKATA for multi device + new 10bit ADC


module counter_8bit_SAKATA (
	input	CLK,
	input	POR,
	input	RST,
	input	COUNT_UP,
	input	[7:0] PERIOD,
	output   reg	[7:0]	COUNT
);


always @( posedge CLK  or negedge POR ) begin
	if (!POR)
		COUNT <= 8'h00;
	else if (RST)
		COUNT <= 8'h00;

	else if (COUNT_UP == 1'b1)begin
		if ( COUNT + 8'h01 < PERIOD)
			COUNT <= COUNT + 8'h01;
		else
			COUNT <= 8'h00;
	end

	else
		COUNT <= COUNT;
end

endmodule