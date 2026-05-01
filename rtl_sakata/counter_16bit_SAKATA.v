//counter_16bit_SAKATA for multi device + new 10bit ADC


module counter_16bit_SAKATA (
	input	CLK,
	input	POR,
	input	RST,
	input	COUNT_UP,
	input	[15:0] PERIOD,
	output   reg	[15:0]	COUNT
);

always @( posedge CLK  or negedge POR ) begin
	if (!POR)
		COUNT <= 16'h0000;
	else if (RST)
		COUNT <= 16'h0000;

	else if (COUNT_UP == 1'b1)begin
		if ( COUNT + 16'h0001 < PERIOD)
			COUNT <= COUNT + 16'h0001;
		else
			COUNT <= 16'h0000;
	end

	else
		COUNT <= COUNT;
end


endmodule