`timescale 1ns/1ns

module SELECT_tb;
reg CLK,ADC_state,POR,ENABLE;
wire C_OUT1,S_OUT,TYPE;
wire [7:0] ADDRESS;
wire OUT;
wire [2:0] state;
wire [7:0] comcon_out;

assign C_OUT1 = 1'b1;
assign ADDRESS [7:0] = 8'b1000_0001;
assign TYPE = 1'b1; 
assign S_OUT = 1'b0;

wire [3:0] cnt2;
assign CLK5 = (cnt2 == 4'd1);
counter_4bit CLK5_divider(.CLK(CLK),.POR(POR),.RST(ADC_state),.COUNT_UP(1'b1),.PERIOD(4'd2),.COUNT(cnt2));

SELECT SELECT(.CLK(CLK),.CLK5(CLK5),.POR(POR),.ADC_state(ADC_state),.C_OUT1(C_OUT1),
              .S_OUT(S_OUT),.TYPE(TYPE),.ENABLE(ENABLE),.ADDRESS(ADDRESS),.OUT(OUT),.state(state),.comcon_out(comcon_out));


always begin
     CLK = 1'b1;
#50 CLK = 1'b0;
#50;
end

initial fork
          POR = 1'b0;
#300   POR = 1'b1;
join

initial fork
          ENABLE = 1'b0;
#2000   ENABLE = 1'b1;
#28000  ENABLE = 1'b0;
join

initial fork
          ADC_state = 1'b1;
#1000   ADC_state = 1'b0;
#450000 ADC_state = 1'b1;
join

endmodule
