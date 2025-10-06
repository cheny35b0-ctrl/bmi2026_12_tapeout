//SELECT_2in for multi device + new 10bit ADC

module SELECT_2in (
    input CLK, SEL1, SEL2, IN1, IN2, POR, RST,
    output reg OUT
);

//OUT
always@(posedge CLK or negedge POR)begin
    if(!POR)
      OUT <= 1'b0;
    else if(RST)
      OUT <= 1'b0;
    else if(SEL1)
      OUT <= IN1;
    else if(SEL2)
      OUT <= IN2;
    else
      OUT <= 1'b0;
end


endmodule