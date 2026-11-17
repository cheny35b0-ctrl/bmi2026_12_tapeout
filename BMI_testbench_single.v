//Verilog HDL for "BMI_digital_sakata", "BMI_TB_sakata" "functional"

`timescale 1ns/1ns
module BMI_testbench_single (


output reg CLK,IN,RST,
output wire MAN,
output reg [399:0] command = 400'b0

);

parameter delay = 0;
parameter clock = 100;
parameter msec = 1000_000;
parameter usec = 1000;

//reg [399:0] command = 400'b0;
reg [399:0] command1 = 400'b0;
reg [399:0] command2 = 400'b0;
reg [7:0] address =8'b1111_1111;


always begin
	CLK = 1'b1;
#50	CLK = 1'b0;
#50;
end

integer I;
integer J;
integer K;
integer L;
integer M;
integer N;

initial begin

//#80000; //wait for POR rise

//command for device0
@(posedge CLK)#delay IN = 1'b0; RST = 1'b0;
#(5*clock);
@(posedge CLK) #delay IN = 1'b0; RST = 1'b1;
		command [7:0]     = 8'b0000_0000;//address
		command [17:10]   = 8'b1010_0000;//enable

		{command [37:30],command[27:20]}    = 16'h000A;//ele_p period
		{command [57:50],command[47:40]}    = 16'h0005;//ele_p width
		{command [77:70],command[67:60]}    = 16'h0002;//ele_p loop
		{command [97:90],command[87:80]}    = 16'h0001;//ele_p delay
		command [107:100]   = 8'b00_1_11111;//enable & intensity

		{command [127:120],command[117:110]}    = 16'h000A;//ele_n period
		{command [147:140],command[137:130]}    = 16'h0005;//ele_n width
		{command [167:160],command[157:150]}    = 16'h0002;//ele_n loop
		{command [187:180],command[177:170]}    = 16'h0006;//ele_n delay
		command [197:190]   = 8'b00_1_11111;//enable & intensity

		{command [217:210],command[207:200]}    = 16'h0000;//ele_meas delay
		command [227:220]   = 8'b0000_1111;//

		{command [247:240],command[237:230]}    = 16'h000A;//opt period
		{command [267:260],command[257:250]}    = 16'h0002;//opt width
		{command [287:280],command[277:270]}    = 16'h0002;//opt loop
		{command [307:300],command[297:290]}    = 16'h0000;//opt delay
		command [317:310]   = 8'b0001_1111;// intensity

		{command [337:330],command[327:320]}    = 16'h0000;//opt_meas delay
		command [347:340]   = 8'b0000_1111;//

//command for device1
@(posedge CLK)#delay IN = 1'b0; RST = 1'b0;
#(5*clock);
@(posedge CLK) #delay IN = 1'b0; RST = 1'b1;
		command1 [7:0]     = 8'b0000_0011;//address
		command1 [17:10]   = 8'b1010_0000;//enable

		{command1 [37:30],command1[27:20]}    = 16'h000A;//ele_p period
		{command1 [57:50],command1[47:40]}    = 16'h0005;//ele_p width
		{command1 [77:70],command1[67:60]}    = 16'h0002;//ele_p loop
		{command1 [97:90],command1[87:80]}    = 16'h0001;//ele_p delay
		command1 [107:100]   = 8'b00_1_11111;//enable & intensity

		{command1 [127:120],command1[117:110]}    = 16'h000A;//ele_n period
		{command1 [147:140],command1[137:130]}    = 16'h0005;//ele_n width
		{command1 [167:160],command1[157:150]}    = 16'h0002;//ele_n loop
		{command1 [187:180],command1[177:170]}    = 16'h0006;//ele_n delay
		command1 [197:190]   = 8'b00_1_11111;//enable & intensity

		{command1 [217:210],command1[207:200]}    = 16'h0000;//ele_meas delay
		command1 [227:220]   = 8'b0000_1111;//

		{command1 [247:240],command1[237:230]}    = 16'h000A;//opt period
		{command1 [267:260],command1[257:250]}    = 16'h0002;//opt width
		{command1 [287:280],command1[277:270]}    = 16'h0002;//opt loop
		{command1 [307:300],command1[297:290]}    = 16'h0000;//opt delay
		command1 [317:310]   = 8'b0001_1111;// intensity

		{command1 [337:330],command[327:320]}    = 16'h0000;//opt_meas delay
		command1 [347:340]   = 8'b0000_1111;//

//command for device2
@(posedge CLK)#delay IN = 1'b0; RST = 1'b0;
#(5*clock);
@(posedge CLK) #delay IN = 1'b0; RST = 1'b1;
		command2 [7:0]     = 8'b0000_0111;//address
		command2 [17:10]   = 8'b1010_0000;//enable

		{command2 [37:30],command2[27:20]}    = 16'h000A;//ele_p period
		{command2 [57:50],command2[47:40]}    = 16'h0005;//ele_p width
		{command2 [77:70],command2[67:60]}    = 16'h0002;//ele_p loop
		{command2 [97:90],command2[87:80]}    = 16'h0001;//ele_p delay
		command2 [107:100]   = 8'b00_1_11111;//enable & intensity

		{command2 [127:120],command2[117:110]}    = 16'h000A;//ele_n period
		{command2 [147:140],command2[137:130]}    = 16'h0005;//ele_n width
		{command2 [167:160],command2[157:150]}    = 16'h0002;//ele_n loop
		{command2 [187:180],command2[177:170]}    = 16'h0006;//ele_n delay
		command2 [197:190]   = 8'b00_1_11111;//enable & intensity

		{command2 [217:210],command2[207:200]}    = 16'h0000;//ele_meas delay
		command2 [227:220]   = 8'b0000_1111;//

		{command2 [247:240],command2[237:230]}    = 16'h000A;//opt period
		{command2 [267:260],command2[257:250]}    = 16'h0002;//opt width
		{command2 [287:280],command2[277:270]}    = 16'h0002;//opt loop
		{command2 [307:300],command2[297:290]}    = 16'h0000;//opt delay
		command2 [317:310]   = 8'b0001_1111;// intensity

		{command2 [337:330],command2[327:320]}    = 16'h0000;//opt_meas delay
		command2 [347:340]   = 8'b0000_1111;//

//IN for device0
for(I =0; I < 1; I = I+1)begin

@(posedge CLK) #delay IN = 1'b0;RST = 1'b0;

@(posedge CLK) #delay IN = 1'b1;RST = 1'b1;
#(10*clock);

	for(J =0; J < 350; J = J+10)begin
		@(posedge CLK) #delay; IN = 1'b0;

		@(posedge CLK) #delay; IN = command[J];
		@(posedge CLK) #delay; IN = command[J+1];
		@(posedge CLK) #delay; IN = command[J+2];
		@(posedge CLK) #delay; IN = command[J+3];
		@(posedge CLK) #delay; IN = command[J+4];
		@(posedge CLK) #delay; IN = command[J+5];
		@(posedge CLK) #delay; IN = command[J+6];
		@(posedge CLK) #delay; IN = command[J+7];

		@(posedge CLK) #delay; IN = 1'b1;
	end

@(posedge CLK) #delay IN = 1'b0;
#(10*clock);
@(posedge CLK) #delay IN = 1'b1;
@(posedge CLK) #delay IN = 1'b0;
#(10*clock);
end
/*
//IN for device1
for(K =0; K < 1; K = K+1)begin

@(posedge CLK) #delay IN = 1'b0;RST = 1'b0;

@(posedge CLK) #delay IN = 1'b1;RST = 1'b1;
#(10*clock);

	for(L =0; L < 350; L = L+10)begin
		@(posedge CLK) #delay; IN = 1'b0;

		@(posedge CLK) #delay; IN = command1[L];
		@(posedge CLK) #delay; IN = command1[L+1];
		@(posedge CLK) #delay; IN = command1[L+2];
		@(posedge CLK) #delay; IN = command1[L+3];
		@(posedge CLK) #delay; IN = command1[L+4];
		@(posedge CLK) #delay; IN = command1[L+5];
		@(posedge CLK) #delay; IN = command1[L+6];
		@(posedge CLK) #delay; IN = command1[L+7];

		@(posedge CLK) #delay; IN = 1'b1;
	end

@(posedge CLK) #delay IN = 1'b0;
#(10*clock);
@(posedge CLK) #delay IN = 1'b1;
@(posedge CLK) #delay IN = 1'b0;
#(10*clock);
end

//IN for device2
for(M =0; M < 1; M = M+1)begin

@(posedge CLK) #delay IN = 1'b0;RST = 1'b0;

@(posedge CLK) #delay IN = 1'b1;RST = 1'b1;
#(10*clock);

	for(N =0; N < 350; N = N+10)begin
		@(posedge CLK) #delay; IN = 1'b0;

		@(posedge CLK) #delay; IN = command2[N];
		@(posedge CLK) #delay; IN = command2[N+1];
		@(posedge CLK) #delay; IN = command2[N+2];
		@(posedge CLK) #delay; IN = command2[N+3];
		@(posedge CLK) #delay; IN = command2[N+4];
		@(posedge CLK) #delay; IN = command2[N+5];
		@(posedge CLK) #delay; IN = command2[N+6];
		@(posedge CLK) #delay; IN = command2[N+7];

		@(posedge CLK) #delay; IN = 1'b1;
	end

@(posedge CLK) #delay IN = 1'b0;
#(10*clock);
@(posedge CLK) #delay IN = 1'b1;
@(posedge CLK) #delay IN = 1'b0;
#(10*clock);
end
*/

//operation command
@(posedge CLK) #delay IN = 1'b1;RST = 1'b0;
#(10*clock);
@(posedge CLK) #delay; IN = 1'b0;RST = 1'b1;

		@(posedge CLK) #delay; IN = address[0];
		@(posedge CLK) #delay; IN = address[1];
		@(posedge CLK) #delay; IN = address[2];
		@(posedge CLK) #delay; IN = address[3];
		@(posedge CLK) #delay; IN = address[4];
		@(posedge CLK) #delay; IN = address[5];
		@(posedge CLK) #delay; IN = address[6];
		@(posedge CLK) #delay; IN = address[7];

		@(posedge CLK) #delay; IN = 1'b1;
		@(posedge CLK) #delay; IN = 1'b0;

		@(posedge CLK) #delay; IN = 1'b1;//operation start
		@(posedge CLK) #delay; IN = 1'b0;


end

assign MAN = (CLK ^| IN);

endmodule
