//counter_4bit_SAKATA for multi device + new 10bit ADC


module counter_4bit_SAKATA (
	input	CLK, //clock
	input	POR, //power on reset
	input	RST, //Synchronous reset
	input	COUNT_UP, //enable signal
	input	[3:0] PERIOD, // period
	output   reg	[3:0]	COUNT // output
);

always @( posedge CLK  or negedge POR ) begin
	if (!POR)
		COUNT <= 4'b0000;  //When the circuit is powerd on, reset resister
	else if (RST)
		COUNT <= 4'b0000;  //When reset signal is 1, reset resister

	else if (COUNT_UP == 1'b1)begin //Count up when enable signal is 1
		if ( COUNT + 4'b0001 < PERIOD) //count up
			COUNT <= COUNT + 4'b0001;
		else
			COUNT <= 4'b0000; // If counter reachs PERIOD, returns to start(4'b0000)
	end

	else
		COUNT <= COUNT; //when enable signal is 0, hold the value
end

endmodule