//SELECT for multi device + new 10bit ADC


module SELECT_SAKATA (
    input CLK, CLK25, POR, ADC_state, C_OUT1, S_OUT, TYPE, ENABLE,
    input [7:0] ADDRESS,
    output reg OUT,
    output reg [2:0] state,
    output [7:0] comcon_out
);


localparam none = 3'b000, counter = 3'b001, address = 3'b010 ,type = 3'b011, shift = 3'b100,  stop = 3'b101, fin = 3'b110;

counter_8bit_SAKATA COMCON_OUT_SAKATA(
.CLK(CLK25),
.POR(POR),
.RST(!ENABLE),
.COUNT_UP(ENABLE),
.PERIOD(8'd60),
.COUNT(comcon_out)
);

//address para to seri
reg [7:0] P_ADDRESS;
reg S_ADDRESS;


always@(posedge CLK or negedge POR)begin
    if(!POR)
      P_ADDRESS <= 8'b0;
    else if(state == counter)
      P_ADDRESS[7:0] <= ADDRESS[7:0];
    else if((state == address) && (CLK25 == 1'b1))
      P_ADDRESS <= P_ADDRESS >>1;
    else
      P_ADDRESS <= P_ADDRESS;
end

always@(posedge CLK or negedge POR)begin
    if(!POR)
      S_ADDRESS <= 1'b0;
    else if(state == counter)
      S_ADDRESS <= 1'b0;
    else if(state == address)
      S_ADDRESS <= P_ADDRESS[0];
    else
      S_ADDRESS <= S_ADDRESS;
end

//SELECTOR   
always@(posedge CLK or negedge POR)begin
       if (POR == 1'b0)
          state <= none;
       else if(ADC_state == 1'b1)
          state <= none;
       else if(ENABLE == 1'b0)
          state <= none;
       else
         case(state)
            none:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd1))
                state <= counter;
              else
                state <= none;
            counter:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd34))
                state <= address;
              else
                state <= counter;
            address:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd42))
                state <= type;
              else
                state <= address;
            type:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd43))
                state <= shift;
              else
                state <= type;
            shift:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd54))
                state <= stop;
              else
                state <= shift;
            stop:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd57))
                state <= fin;
              else
                state <= stop;
            fin:
              if(ENABLE == 1'b0)
                state <= none;
              else
                state <= fin;
           default state <= none;
         endcase
end




always@(posedge CLK or negedge POR)begin
       if(!POR)
           OUT <= 1'b0;
       else if (state == none)
           OUT <= 1'b0;
       else if(CLK25 == 1'b1)
           if(state == counter)
           OUT <= C_OUT1;
           else if(state == shift)
           OUT <= S_OUT;
           else if(state == address)
           OUT <= S_ADDRESS;
           else if(state == type)
           OUT <= TYPE;
           else if(state == stop)
           OUT <= 1'b1;
           else if(state == fin)
           OUT <= 1'b0;
           else
           OUT <= OUT;
       else
           OUT <= OUT;

end

endmodule