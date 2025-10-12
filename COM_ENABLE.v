
module COM_ENABLE(
     input CLK,POR,ADC_STATE,
     input [3:0] DELAY,
     input [1:0] OPERATE,
     output reg ENABLE,
     outputCLK5
     //output reg [2:0] state

);
//ENABLE generation
localparam none = 3'b000, delay = 3'b001, on = 3'b010, fin = 3'b011;

wire [15:0] clk_div_500,en_last;
reg state_EN;

counter_16bit COM_DELAY(.CLK(CLK),.POR(POR),.RST(!state_EN),
                        .COUNT_UP(ADC_STATE == 1'b0),.PERIOD(16'd500),.COUNT(clk_div_500));

counter_16bit EN_LAST(.CLK(CLK),.POR(POR),.RST(!state_EN),.COUNT_UP(ENABLE),.PERIOD(16'd500),.COUNT(en_last));

reg [2:0] state;
wire [7:0] address_delay;
reg ADC_delay, ADC_edge;

always@(posedge CLK or negedge POR) begin
    if(!POR) begin
       ADC_edge <= 1'b0;
       ADC_delay <= 1'b0;
       end
    else begin
       ADC_edge <= !ADC_STATE && ADC_delay;
       ADC_delay <= ADC_STATE;
      end
end      

// クロックの立ち上がりエッジまたはリセットの立ち下がりエッジで動作
// TODO 同じ条件だからまとめる。
always@(posedge CLK or negedge POR) begin
   if(!POR)
    state_EN <= 1'b0;
   else if(!ADC_STATE)
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
            // DELAY == 0の場合はadc変換終了直後にon
            if((|OPERATE) && (DELAY == 4'b0000) && (state_EN == 1'b1))
                     state <= on;
            // それ以外の場合はADC変換終了直後にdelayへ
            // state_ENが1の時address_delayは0になる。
            // ちなみにdelayに状態が遷移するまではずっと0のまま
            else if ((|OPERATE) && (DELAY >= address_delay) && (state_EN == 1'b1))
                     state <= delay;
            else
                     state <= none;
         delay:
            // addressに対して順番にonになる
            if((|OPERATE) && (DELAY == address_delay))
                     state <= on;
            else
                     state <= delay;
         on:
            // 通信時間を測定
            if((|OPERATE) && (en_last > 16'd237))
                     state <= fin;
            else
                     state <= on;
         fin:
            if((|OPERATE) && (ADC_STATE == 1'b1))
                     state <= none;
            else
                     state <= fin;

          default: state <= none;
          endcase
end

counter_8bit delay_counter(.CLK(CLK),.POR(POR),.RST(!state_EN),
                           .COUNT_UP( (state == delay) && (clk_div_500 ==16'd499)),
                           .PERIOD(8'b0001_0000),.COUNT(address_delay));

always@(posedge CLK or negedge POR)begin
      if (!POR)
         ENABLE <= 1'b0;
      else if(state == on)
         ENABLE <= 1'b1;
      else
         ENABLE <= 1'b0;
end

//CLK50 generation
wire [3:0] cnt2;
assign CLK50 = (cnt2 == 4'd1);
counter_4bit CLK50_divider(.CLK(CLK),.POR(POR),.RST(!state_EN),.COUNT_UP((|OPERATE)&&(ADC_STATE==1'b0)),.PERIOD(4'd2),.COUNT(cnt2));

endmodule