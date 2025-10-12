//SHIFT_REG for multi device + new 10bit ADC


module SHIFT_REG (
    input CLK, ADC_STATE, POR,CLK5, ENABLE,
    input [2:0] state,
    input [19:0] DATA,
    output reg S_OUT

);

localparam none = 3'b000, counter = 3'b001, address = 3'b010, type = 3'b011, shift = 3'b100, stop = 3'b101, fin = 3'b110;

reg [20:0] shift_reg;


//shift_reg
always@(posedge CLK or negedge POR)begin
    if(!POR)
      shift_reg <= 21'b0;
    else if(!ENABLE)
      shift_reg <= 21'b0;
    else if(state == type)
      shift_reg <= {DATA[19:0],1'b0};
    else if((CLK5 == 1'b1) && (state == shift))
      shift_reg <= shift_reg >>1;
    else
      shift_reg <= shift_reg;
end
always@(posedge CLK or negedge POR)begin
    if(!POR) 
     S_OUT <= 1'b0;
    else
     S_OUT <= shift_reg[0];
end
endmodule