//SELECT for multi device + new 10bit ADC + convolutional encoding


module SELECT (
    input CLK, CLK5, POR, ADC_STATE, C_OUT1, S_OUT, ENABLE,
    input [1:0] TYPE,
    input [7:0] ADDRESS,
    input ENCODE_ENABLE,           // 符号化ON/OFFフラグ
    output reg OUT,
    output reg [2:0] state
);

wire [7:0] comcon_out;

// 状態定義（encode追加のため、stopとfinの値を変更）
localparam none = 3'b000, counter = 3'b001, address = 3'b010, type = 3'b011, shift = 3'b100, encode = 3'b101, stop = 3'b110, fin = 3'b111;

counter_8bit COMCON_OUT(
.CLK(CLK5),
.POR(POR),
.RST(!ENABLE),
.COUNT_UP(ENABLE),
.PERIOD(8'd110),
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
    else if((state == address) && (CLK5 == 1'b1))
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

//type para to seri
reg [1:0] P_TYPE;
reg S_TYPE;

always@(posedge CLK or negedge POR)begin
    if(!POR)
      P_TYPE <= 2'b0;
    else if(state == address)
      P_TYPE[1:0] <= TYPE[1:0];
    else if((state == type) && (CLK5 == 1'b1))
      P_TYPE <= P_TYPE >>1;
    else
      P_TYPE <= P_TYPE;
end

always@(posedge CLK or negedge POR)begin
    if(!POR)
      S_TYPE <= 1'b0;
    else if(state == address)
      S_TYPE <= 1'b0;
    else if(state == type)
      S_TYPE <= P_TYPE[0];
    else
      S_TYPE <= S_TYPE;
end

//SELECTOR
always@(posedge CLK or negedge POR)begin
       if (POR == 1'b0)
          state <= none;
       else if(ADC_STATE == 1'b1)
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
              // 32クロックのスタートカウント完了後
              if((ENABLE == 1'b1) && (comcon_out >= 8'd33)) begin
                if(ENCODE_ENABLE)
                  state <= encode;     // 符号化ON: encodeへ
                else
                  state <= address;    // 符号化OFF: addressへ
              end
              else
                state <= counter;
            // 以下は符号化OFF時のパス
            address:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd41))
                state <= type;
              else
                state <= address;
            type:
              if((ENABLE == 1'b1) && (comcon_out >= 8'd43))
                state <= shift;
              else
                state <= type;
            shift:
              // 20bitシフト完了後（30bitデータの場合は+10bit）
              if((ENABLE == 1'b1) && (comcon_out >= 8'd63))
                state <= stop;
              else
                state <= shift;
            // 符号化ON時のパス
            encode:
              // 64bitシフト完了後
              if((ENABLE == 1'b1) && (comcon_out >= 8'd97))
                state <= stop;
              else
                state <= encode;
            // 共通パス
            stop:
              // 符号化ON時は100、OFF時は66で終了
              if(ENCODE_ENABLE) begin
                if((ENABLE == 1'b1) && (comcon_out >= 8'd100))
                  state <= fin;
                else
                  state <= stop;
              end
              else begin
                if((ENABLE == 1'b1) && (comcon_out >= 8'd66))
                  state <= fin;
                else
                  state <= stop;
              end
            fin:
              if(ENABLE == 1'b0)
                state <= none;
              else
                state <= fin;
           default: state <= none;
         endcase
end




always@(posedge CLK or negedge POR)begin
       if(!POR)
           OUT <= 1'b0;
       else if (state == none)
           OUT <= 1'b0;
       else if (CLK5 == 1'b1)
           if(state == counter)
              OUT <= C_OUT1;
           else if(state == shift)
              OUT <= S_OUT;
           else if(state == encode)
              // 符号化ON時: SHIFT_REGからの出力（S_OUT）を使用
              OUT <= S_OUT;
           else if(state == address)
              OUT <= S_ADDRESS;
           else if(state == type)
              OUT <= S_TYPE;
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