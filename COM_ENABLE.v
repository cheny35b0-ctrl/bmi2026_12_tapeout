
module COM_ENABLE(
     input CLK,POR,ADC_state,
     input [3:0] DELAY,
     input OPERATE, 
     input [9:0] def_delay,
     output reg ENABLE,
     output CLK5
     //output reg [2:0] state

);
//ENABLE generation
localparam none = 3'b000, delay = 3'b001, delay_last = 3'b010, on = 3'b011, fin = 3'b100;

wire [15:0] com_delay,en_last;
reg state_EN;

counter_16bit COM_DELAY(.CLK(CLK),.POR(POR),.RST(!state_EN),
                        .COUNT_UP(ADC_state == 1'b0),.PERIOD(16'd500),.COUNT(com_delay));

counter_16bit EN_LAST(.CLK(CLK),.POR(POR),.RST(!state_EN),.COUNT_UP(ENABLE),.PERIOD(16'd500),.COUNT(en_last));

reg [2:0] state;
wire [7:0] address_delay;
reg ADC_delay, ADC_edge;

// クロックの立ち上がりエッジまたはリセットの立ち下がりエッジで動作
always@(posedge CLK or negedge POR) begin
    if(!POR) begin
       ADC_edge <= 1'b0;
       ADC_delay <= 1'b0;
       end
    else begin
       ADC_edge <= !ADC_state && ADC_delay;
       ADC_delay <= ADC_state;
      end
end      

// クロックの立ち上がりエッジまたはリセットの立ち下がりエッジで動作
// TODO 同じ条件だからまとめる。
// 複数行にわたっている場合はbegin endで囲む
always@(posedge CLK or negedge POR) begin
   if(!POR)
    state_EN <= 1'b0;
   else if(!ADC_state)
     if(ADC_edge)
        state_EN <= 1'b1;
     else
        state_EN <= state_EN;
   else
     state_EN <= 1'b0;
end
 
always@(posedge CLK or negedge POR) begin
    if(!POR)
      state <= none;
    else
       case(state)
         none:
            if((OPERATE == 1'b1) && (DELAY == 4'b0000) && (def_delay == 10'd0) && (state_EN == 1'b1))
                     state <= on;
            else if ((OPERATE == 1'b1) && (DELAY >= address_delay) && (state_EN == 1'b1))
                     state <= delay;
            else
                     state <= none;
         delay:
            if((OPERATE == 1'b1) && (DELAY == address_delay) && (def_delay == 10'd0))
                     state <= on;
            else if((OPERATE == 1'b1) && (DELAY <= address_delay) && (def_delay > 10'd0))
                     state <= delay_last;
            else
                     state <= delay;
         delay_last:
            if((OPERATE == 1'b1) && (DELAY <= address_delay) && (def_delay <= com_delay))
                     state <= on;
            else
                     state <= delay_last;
         on:
            if((OPERATE == 1'b1) && (en_last > 16'd237))
                     state <= fin;
            else
                     state <= on;
         fin:
            if((OPERATE == 1'b1) && (ADC_state == 1'b1))
                     state <= none;
            else
                     state <= fin;

          default: state <= none;
          endcase
end

counter_8bit delay_counter(.CLK(CLK),.POR(POR),.RST(!state_EN),
                           .COUNT_UP( ( (state == delay)||(state == delay_last) ) && (com_delay ==16'd499)),
                           .PERIOD(8'b0001_0000),.COUNT(address_delay));

always@(posedge CLK or negedge POR)begin
      if (!POR)
         ENABLE <= 1'b0;
      else if(state == on)
         ENABLE <= 1'b1;
      else if(state == none)
         ENABLE <= 1'b0;
      else if(state == fin)
         ENABLE <= 1'b0;
      else
         ENABLE <= 1'b0;
end

//CLK5 generation
wire [3:0] cnt2;
assign CLK5 = (cnt2 == 4'd1);
counter_4bit CLK5_divider(.CLK(CLK),.POR(POR),.RST(!state_EN),.COUNT_UP((OPERATE==1'b1)&&(ADC_state==1'b0)),.PERIOD(4'd2),.COUNT(cnt2));

endmodule