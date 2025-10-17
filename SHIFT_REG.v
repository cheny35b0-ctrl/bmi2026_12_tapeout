//SHIFT_REG for multi device + new 10bit ADC


module SHIFT_REG (
    input CLK, ADC_STATE, POR,CLK5, ENABLE,
    input [2:0] state,
    input [19:0] DATA,
    output reg S_OUT

);

localparam none = 3'b000, counter = 3'b001, address = 3'b010, type = 3'b011, shift = 3'b100, stop = 3'b101, fin = 3'b110;

//data para to seri
reg [19:0] P_DATA;

always@(posedge CLK or negedge POR)begin
    if(!POR)
      P_DATA <= 20'b0;
    else if(!ENABLE)
      P_DATA <= 20'b0;
    else if(state == type)
      P_DATA[19:0] <= DATA[19:0];
    else if((state == shift) && (CLK5 == 1'b0))
      P_DATA <= P_DATA >>1;
    else
      P_DATA <= P_DATA;
end

always@(posedge CLK or negedge POR)begin
    if(!POR)
      S_OUT <= 1'b0;
    else if(!ENABLE)
      S_OUT <= 1'b0;
    else if((state == type) || (state == shift))
      S_OUT <= P_DATA[0];
    else
      S_OUT <= S_OUT;
end
endmodule