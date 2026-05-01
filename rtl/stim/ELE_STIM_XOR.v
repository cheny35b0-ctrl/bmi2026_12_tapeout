//Verilog HDL for "BMI18_digital_refactoring", "ELE_STIM_XOR" "functional"


module ELE_STIM_XOR (

	input CLK,POR,

	input [4:0] P_STIM,
	input [4:0] N_STIM,

	output reg [4:0] P_STIM_XOR,
	output reg [4:0] N_STIM_XOR,

	output reg P_STIM_EN_XOR,
	output reg N_STIM_EN_XOR

);

wire p_stim_en;
assign	p_stim_en = | P_STIM[4:0];

wire n_stim_en;
assign	n_stim_en = | N_STIM[4:0];

always @(posedge CLK or negedge POR)begin
	if(!POR)
		P_STIM_XOR [4:0] <= 5'b0000;
	else
		P_STIM_XOR [4:0] <= P_STIM[4:0] &  {5{~n_stim_en}} ;
end

always @(posedge CLK or negedge POR)begin
	if(!POR)
		N_STIM_XOR [4:0] <= 5'b0000;
	else
		N_STIM_XOR [4:0] <= N_STIM[4:0] &  {5{~p_stim_en}} ;
end

always @(posedge CLK or negedge POR)begin
	if(!POR)
		P_STIM_EN_XOR <= 1'b0;
	else
		P_STIM_EN_XOR <= p_stim_en & (~n_stim_en) ;
end

always @(posedge CLK or negedge POR)begin
	if(!POR)
		N_STIM_EN_XOR <= 1'b0;
	else
		N_STIM_EN_XOR <= n_stim_en & (~p_stim_en) ;
end


endmodule
