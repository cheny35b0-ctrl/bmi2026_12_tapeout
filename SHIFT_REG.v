//SHIFT_REG for multi device + new 10bit ADC + convolutional encoding


module SHIFT_REG (
    input CLK, ADC_STATE, POR, CLK5, ENABLE,
    input [2:0] state,
    input [63:0] DATA,             // 64bitに拡張（符号化ON時は64bit、OFF時は20bit使用）
    input ENCODE_ENABLE,           // 符号化ON/OFFフラグ
    input ENCODE_DONE,             // 符号化完了信号
    output reg S_OUT

);

localparam none = 3'b000, counter = 3'b001, address = 3'b010, type = 3'b011, shift = 3'b100, encode = 3'b101, stop = 3'b110, fin = 3'b111;

reg [63:0] shift_reg;              // 64bitシフトレジスタに拡張
reg encode_loaded;                 // encode状態でのロード完了フラグ

// encode_loadedフラグ制御
always@(posedge CLK or negedge POR)begin
    if(!POR)
      encode_loaded <= 1'b0;
    else if(state != encode)
      encode_loaded <= 1'b0;
    else if(ENCODE_ENABLE && (state == counter) && ENCODE_DONE && !encode_loaded)
      encode_loaded <= 1'b1;
end

always@(posedge CLK or negedge POR)begin
    if(!POR)
      shift_reg <= 64'b0;
    else if(!ENABLE)
      shift_reg <= 64'b0;
    else if(!ENCODE_ENABLE && (state == type))
      // 符号化OFF時: type状態でDATAの20bitロード
      shift_reg <= DATA[63:0];
    else if(ENCODE_ENABLE && (state == counter) && ENCODE_DONE && !encode_loaded)
      // 符号化ON時: encode状態でENCODE_DONE後の最初だけ64bitロード
      shift_reg <= DATA[63:0];
    else if((CLK5 == 1'b0) && ((state == shift) || (state == encode)))
      // シフト動作（encode状態でもシフト可能に）
      shift_reg <= shift_reg >> 1;
    else
      shift_reg <= shift_reg;
end

always@(posedge CLK or negedge POR)begin
    if(!POR)
      S_OUT <= 1'b0;
    else if(!ENABLE)
      S_OUT <= 1'b0;
    else if((state == counter) || (state == type) || (state == shift) || (state == encode))
      S_OUT <= shift_reg[0];
    else
      S_OUT <= S_OUT;
end

endmodule