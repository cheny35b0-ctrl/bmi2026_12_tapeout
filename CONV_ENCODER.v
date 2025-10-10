// CONV_ENCODER.v - Convolutional Encoder (K=3, rate 1/2, G=(7,5))
// 畳み込み符号化器
// 拘束長K=3、符号化率1/2、生成多項式G0=7(111), G1=5(101)

module CONV_ENCODER (
    input CLK,
    input POR,
    input START,                    // 符号化開始信号
    input [31:0] DATA_IN,          // 入力データ（32bit: 30bit + 終端2bit）
    output reg [63:0] DATA_OUT,    // 符号化後データ（64bit）
);

// 内部レジスタ
reg [1:0] state;                   // シフトレジスタ（S1, S0）
reg [5:0] bit_counter;             // ビットカウンタ（0～31）
reg [63:0] encoded_data;           // 出力バッファ
reg encoding;                      // 符号化中フラグ

// 生成多項式
// G0 = 7 (111): c0 = d[k] XOR S0 XOR S1
// G1 = 5 (101): c1 = d[k] XOR S1

// ASK ここのwireっているの？
// 下でassignしているけどどこと繋がっているのかが全然わからない。
wire input_bit;
wire c0, c1;

// 入力ビット選択（MSB first: ADDRESS[7]から開始）
// input_bitには1bit分のデータが入る
assign input_bit = DATA_IN[31 - bit_counter];

// 符号化出力計算
// XORで計算する
assign c0 = input_bit ^ state[0] ^ state[1];  // G0 = 111
assign c1 = input_bit ^ state[1];              // G1 = 101

// メイン処理
always @(posedge CLK or negedge POR) begin
    if (!POR) begin
        state <= 2'b00;
        bit_counter <= 6'd0;
        encoded_data <= 64'b0;
        encoding <= 1'b0;
        DATA_OUT <= 64'b0;
    end
    else if (START && !encoding) begin
        // 符号化開始
        state <= 2'b00;
        bit_counter <= 6'd0;
        encoded_data <= 64'b0;
        encoding <= 1'b1;
    end
    else if (encoding) begin
        // 符号化処理
        // 出力ビット格納（c0を先に、次にc1）LSBファースト
        encoded_data[(bit_counter * 2)] <= c0;
        encoded_data[(bit_counter * 2 + 1)] <= c1;

        // 状態更新（シフトレジスタ）
        // 次の計算用にstateの状態をシフトしている
        state <= {state[0], input_bit};


        // カウンタ更新
        if (bit_counter == 6'd31) begin
            // 符号化完了
            DATA_OUT <= encoded_data;
            encoding <= 1'b0;
        end
        else begin
            bit_counter <= bit_counter + 1;
        end
    end
end

endmodule
