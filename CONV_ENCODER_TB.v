// CONV_ENCODER_TB.v - Testbench for Convolutional Encoder
// 畳み込み符号化器テストベンチ

`timescale 1ns/1ns

module CONV_ENCODER_TB;

// パラメータ定義
parameter clock = 100;  // 100nsクロック周期（10MHz）
parameter delay = 0;

// テスト信号
reg CLK;
reg POR;
reg START;
reg [31:0] DATA_IN;
wire [63:0] DATA_OUT;
wire ENCODE_DONE;

// DUT（Design Under Test）インスタンス化
CONV_ENCODER uut (
    .CLK(CLK),
    .POR(POR),
    .START(START),
    .DATA_IN(DATA_IN),
    .DATA_OUT(DATA_OUT),
    .ENCODE_DONE(ENCODE_DONE)
);

// クロック生成（100ns周期 = 10MHz）
always begin
    CLK = 1'b1;
    #50 CLK = 1'b0;
    #50;
end

// テストシーケンス
initial begin
    $display("=== Convolutional Encoder Testbench Start ===");

    // 初期化
    POR = 1'b0;
    START = 1'b0;
    DATA_IN = 32'h00000000;

    // パワーオンリセット解除
    #200;
    @(posedge CLK) #delay POR = 1'b1;
    $display("[%0t ns] POR released", $time);

    // テストケース1: 全ビット0の入力
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'h00000000;
    START = 1'b1;
    $display("[%0t ns] Test Case 1: DATA_IN = 0x%08h", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    // 符号化完了待ち
    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 1 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テストケース2: 全ビット1の入力
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'hFFFFFFFF;
    START = 1'b1;
    $display("[%0t ns] Test Case 2: DATA_IN = 0x%08h", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 2 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テストケース3: 交互パターン（10101010...）
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'hAAAAAAAA;
    START = 1'b1;
    $display("[%0t ns] Test Case 3: DATA_IN = 0x%08h", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 3 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テストケース4: 交互パターン（01010101...）
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'h55555555;
    START = 1'b1;
    $display("[%0t ns] Test Case 4: DATA_IN = 0x%08h", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 4 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テストケース5: アドレスパターン（例：デバイスアドレス0x00 + データ）
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'h00000000;  // ADDRESS部分を想定
    START = 1'b1;
    $display("[%0t ns] Test Case 5: DATA_IN = 0x%08h (Address pattern)", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 5 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テストケース6: ランダムパターン1
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'h12345678;
    START = 1'b1;
    $display("[%0t ns] Test Case 6: DATA_IN = 0x%08h", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 6 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テストケース7: ランダムパターン2
    #(5*clock);
    @(posedge CLK) #delay;
    DATA_IN = 32'hDEADBEEF;
    START = 1'b1;
    $display("[%0t ns] Test Case 7: DATA_IN = 0x%08h", $time, DATA_IN);
    @(posedge CLK) #delay START = 1'b0;

    @(posedge ENCODE_DONE);
    #(2*clock);
    $display("[%0t ns] Test Case 7 Result: DATA_OUT = 0x%016h", $time, DATA_OUT);

    // テスト終了
    #(10*clock);
    $display("=== Convolutional Encoder Testbench Complete ===");
    $finish;
end

// タイムアウト監視（50us後に強制終了）
initial begin
    #50000;
    $display("[ERROR] Testbench timeout!");
    $finish;
end

// 波形ダンプ（オプション）
initial begin
    $dumpfile("conv_encoder_tb.vcd");
    $dumpvars(0, CONV_ENCODER_TB);
end

endmodule
