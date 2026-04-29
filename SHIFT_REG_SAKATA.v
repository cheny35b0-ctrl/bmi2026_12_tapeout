//SHIFT_REG_SAKATA for multi device + new 10bit ADC


module SHIFT_REG_SAKATA (
    input CLK, ADC_state, POR, CLK25, ENABLE,
    input [2:0] state,
    input [9:0] DATA,
    output reg S_OUT
    
);

reg [10:0] shift_reg;


//shift_reg
always@(posedge CLK or negedge POR)begin
    if(!POR) 
      shift_reg <= 11'b0;
    else if(!ENABLE) 
      shift_reg <= 11'b0;
    else if(state != 3'b100)
      shift_reg <= {DATA[9:0],1'b0};
    else if((CLK25 == 1'b1) && (state == 3'b100))
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