`timescale 1ns/1ns

//
// COM_CON_OUT_tb.v - 通信出力ブロックのテストベンチ
//
// COM_CON_OUT = MEASUREMENT_TYPE_ENCODER + COM_CON_TOP
//               (COM_ENABLE / COUNTER_COMCON / SHIFT_REG / SELECT / CONV_ENCODER)
//
// 検証内容
//   1. S_Bias の立ち下がり (ADC 変換終了) ごとに 1 フレームが送出されること
//   2. 符号化 OFF 時: OUT に ADDRESS / TYPE / DATA がそのまま載ること
//   3. 符号化 ON  時: OUT に CONV_ENCODER の 64bit 出力が載ること
//      (期待値は TB 内の参照モデルで独立に計算する)
//   4. conv_encoder_state による通常モード / デバッグモードのデータ切替
//   5. TYPE が {OPERATE_OPT, OPERATE_ELE} と一致すること
//   6. ADDRESS[5:0] による送信開始ディレイ
//   7. OPERATE が両方 0 のときフレームを出さないこと
//
// 注意: 以前の TB は波形ダンプのみで合否判定が一切なかった。
//

module COM_CON_OUT_tb;

parameter clock = 100;   // CLK 周期 [ns] (10MHz)

// COM_CON_OUT.v の localparam と同じデバッグ用固定データ
localparam [19:0] DEBUG_TEST_DATA = 20'h7B3A9;

// OUT を comcon_out 値で読むときのフィールド位置
localparam PRE_LO      = 2,   PRE_HI      = 34;   // スタートカウンタ 32bit
localparam ADDR_LO     = 35,  ADDR_HI     = 42;   // ADDRESS 8bit (LSB first)
localparam TYPE_LO     = 43,  TYPE_HI     = 44;   // TYPE 2bit    (LSB first)
localparam DATA_LO     = 45,  DATA_HI     = 64;   // DATA 20bit   (LSB first)
localparam STOP_OFF_LO = 65,  STOP_OFF_HI = 67;   // ストップ 3bit (符号化OFF)
localparam ENC_LO      = 35,  ENC_HI      = 98;   // 符号化データ 64bit
localparam STOP_ON_LO  = 99,  STOP_ON_HI  = 101;  // ストップ 3bit (符号化ON)

// COM_ENABLE.v の COM_DELAY カウンタ周期。ADDRESS[5:0] 1 あたりの遅延クロック数
localparam DELAY_STEP = 200;

reg CLK, POR;
reg S_Bias_OPT, S_Bias_ELE;
reg OPERATE_OPT, OPERATE_ELE;
reg [9:0] DATA_OPT, DATA_ELE;
reg [7:0] ADDRESS;
reg ENCODE_ENABLE;        // TOP では command[343] | ENCODE_ENABLE_ext
reg conv_encoder_state;   // デバッグ用モード切替
wire OUT;

// ---------------------------------------------------------------
// DUT
// ---------------------------------------------------------------
COM_CON_OUT COM_CON_OUT(
    .CLK(CLK),
    .POR(POR),
    .S_Bias_OPT(S_Bias_OPT),
    .S_Bias_ELE(S_Bias_ELE),
    .OPERATE_OPT(OPERATE_OPT),
    .OPERATE_ELE(OPERATE_ELE),
    .ADDRESS(ADDRESS),
    .DATA_OPT(DATA_OPT),
    .DATA_ELE(DATA_ELE),
    .ENCODE_ENABLE(ENCODE_ENABLE),
    .conv_encoder_state(conv_encoder_state),
    .OUT(OUT)
);

// CLOCK generation (10MHz, 100ns 周期)
always begin
    CLK = 1'b1;
    #50 CLK = 1'b0;
    #50;
end

// DUT 内部の観測点
wire [2:0] sel_state  = COM_CON_OUT.COM_CON_TOP.SELECT.state;
wire [7:0] sel_comcon = COM_CON_OUT.COM_CON_TOP.SELECT.comcon_out;
wire       com_enable = COM_CON_OUT.COM_CON_TOP.ENABLE;
wire       com_clk5   = COM_CON_OUT.COM_CON_TOP.CLK5;
wire [1:0] meas_code  = COM_CON_OUT.MEASUREMENT_CODE;

// ---------------------------------------------------------------
// セルフチェック
// ---------------------------------------------------------------
integer checks = 0;
integer errors = 0;

// メッセージをタスク引数で渡すと日本語が化けるためマクロで実装している
`define CHECK(cond, msg) \
    begin \
        checks = checks + 1; \
        if (cond) $display("  [PASS] %0s", msg); \
        else begin \
            errors = errors + 1; \
            $display("  [FAIL] %0s", msg); \
        end \
    end

integer i;

// OUT を comcon_out 値ごとに保存する (CLK5 パルスの立ち上がりで採る)
//
// ENABLE はフレーム送出後も 240clk 続き、その間 comcon_out は PERIOD=110 で
// 折り返して 0 から数え直す。そのまま上書きするとフレーム末尾 (fin, OUT=0) が
// 先頭のプリアンブルを潰してしまうため、各インデックス最初の 1 回だけ採る。
reg out_at [0:127];

always @(posedge CLK)
    if (com_clk5 && com_enable && (sel_comcon < 8'd128) && (out_at[sel_comcon] === 1'bx))
        out_at[sel_comcon] = OUT;

// フレーム 1 回分の観測結果
integer frame_seen;      // ENABLE が立ったか
integer frame_timeout;   // フレームが終わらなかったか
time    sbias_fall_t;    // S_Bias が落ちた時刻
time    enable_rise_t;   // ENABLE が立った時刻
integer enable_width;    // ENABLE が立っていたクロック数
integer comcon_peak;     // フレーム中に到達した comcon_out の最大値

always @(posedge CLK)
    if (com_enable && (sel_comcon > comcon_peak)) comcon_peak = sel_comcon;

// 期待値と復元値
reg [19:0] exp_data;
reg [1:0]  exp_type;
reg [31:0] exp_enc_in;
reg [63:0] exp_enc_out;
reg [7:0]  got_addr;
reg [1:0]  got_type;
reg [19:0] got_data;
reg [63:0] got_enc;
integer    preamble_bad;
integer    stop_bad;

// ---------------------------------------------------------------
// 参照モデル
// ---------------------------------------------------------------
// !! 注意: この参照モデル (golden_encode / ビット詰め替え関数) は
//    CONV_ENCODER_TB.v / COM_CON_OUT_tb.v / TOP_202512TO_tb.v の 3 ファイルに
//    同じものがコピーされている。RTL 実装のバグが期待値へコピーされるのを防ぐため、
//    意図的に共有ヘッダ化していない。
//    生成多項式やビット順の仕様を変えるときは 3 ファイルすべてを直すこと。

// COM_CON_TOP.v の encoder_input と同じ並べ替え
// {ADDRESS[0..7], TYPE[0..1], DATA[0..19], 2'b00}
function [31:0] enc_input(input [7:0] a, input [1:0] t, input [19:0] d);
    integer k;
begin
    for (k = 0; k < 8;  k = k + 1) enc_input[31 - k] = a[k];
    for (k = 0; k < 2;  k = k + 1) enc_input[23 - k] = t[k];
    for (k = 0; k < 20; k = k + 1) enc_input[21 - k] = d[k];
    enc_input[1] = 1'b0;
    enc_input[0] = 1'b0;
end
endfunction

// 畳み込み符号化 (K=3, rate 1/2, G0=7(111), G1=5(101), MSB first, ゼロ終端)
// CONV_ENCODER.v とは独立に仕様から書いた参照実装
function [63:0] golden_encode(input [31:0] d);
    integer k;
    reg s0, s1, b;
begin
    s0 = 1'b0;
    s1 = 1'b0;
    golden_encode = 64'b0;
    for (k = 0; k < 32; k = k + 1) begin
        b = d[31 - k];
        golden_encode[k*2]     = b ^ s0 ^ s1;   // c0 : G0 = 111
        golden_encode[k*2 + 1] = b ^ s1;        // c1 : G1 = 101
        s1 = s0;
        s0 = b;
    end
end
endfunction

// ---------------------------------------------------------------
// メインシーケンス
// ---------------------------------------------------------------
initial begin
    $dumpfile("COM_CON_OUT_tb.vcd");
    $dumpvars(0, COM_CON_OUT_tb);

    $display("========================================");
    $display("COM_CON_OUT Testbench");
    $display("========================================");

    POR                = 1'b0;
    S_Bias_OPT         = 1'b0;
    S_Bias_ELE         = 1'b0;
    OPERATE_OPT        = 1'b1;
    OPERATE_ELE        = 1'b1;
    DATA_OPT           = 10'b0;
    DATA_ELE           = 10'b0;
    ADDRESS            = 8'b0;
    ENCODE_ENABLE      = 1'b0;
    conv_encoder_state = 1'b0;
    comcon_peak        = 0;

    #300 POR = 1'b1;

    // ============ 1. 符号化 OFF / 通常モード ============
    $display("\n----------------------------------------");
    $display(" 1. 符号化 OFF / 通常モード (実測データ)");
    $display("----------------------------------------");
    send_frame(1'b0, 1'b0, 8'b1100_0000, 1'b1, 1'b1, 10'b1110_0101_11, 10'b1001_1010_10);
    expect_frame_off;

    // ============ 2. 符号化 ON / 通常モード ============
    $display("\n----------------------------------------");
    $display(" 2. 符号化 ON / 通常モード (実測データ)");
    $display("----------------------------------------");
    send_frame(1'b1, 1'b0, 8'b1100_0000, 1'b1, 1'b1, 10'b1110_0101_11, 10'b1001_1010_10);
    expect_frame_on;

    // ============ 3. 符号化 OFF / デバッグモード ============
    // conv_encoder_state=1 のとき DATA は DEBUG_TEST_DATA に差し替わる
    $display("\n----------------------------------------");
    $display(" 3. 符号化 OFF / デバッグモード (固定データ)");
    $display("----------------------------------------");
    send_frame(1'b0, 1'b1, 8'b0100_0011, 1'b1, 1'b1, 10'h3FF, 10'h000);
    expect_frame_off;

    // ============ 4. 符号化 ON / デバッグモード ============
    $display("\n----------------------------------------");
    $display(" 4. 符号化 ON / デバッグモード (固定データ)");
    $display("----------------------------------------");
    send_frame(1'b1, 1'b1, 8'b1000_0010, 1'b1, 1'b1, 10'h3FF, 10'h000);
    expect_frame_on;

    // ============ 5. TYPE = 光測定のみ ============
    $display("\n----------------------------------------");
    $display(" 5. TYPE 検証: 光測定のみ (OPERATE=10)");
    $display("----------------------------------------");
    send_frame(1'b0, 1'b0, 8'b1100_0001, 1'b1, 1'b0, 10'h155, 10'h2AA);
    expect_frame_off;

    // ============ 6. TYPE = 電気測定のみ ============
    $display("\n----------------------------------------");
    $display(" 6. TYPE 検証: 電気測定のみ (OPERATE=01)");
    $display("----------------------------------------");
    send_frame(1'b1, 1'b0, 8'b1100_0001, 1'b0, 1'b1, 10'h155, 10'h2AA);
    expect_frame_on;

    // ============ 7. 測定なし → 送信しない ============
    $display("\n----------------------------------------");
    $display(" 7. OPERATE 両方 0 ではフレームを出さない");
    $display("----------------------------------------");
    send_frame(1'b0, 1'b0, 8'b1100_0000, 1'b0, 1'b0, 10'h3FF, 10'h3FF);
    expect_no_frame;

    // ===================== 結果サマリ =====================
    $display("\n========================================");
    $display(" テスト結果");
    $display("========================================");
    $display("  チェック項目 : %0d", checks);
    $display("  成功         : %0d", checks - errors);
    $display("  失敗         : %0d", errors);
    $display("========================================");

    if (errors != 0)
        $fatal(1, "TEST FAILED (%0d 件失敗)", errors);

    $display("TEST PASSED");
    $finish;
end

// 全体ウォッチドッグ
initial begin
    #5000000;
    $fatal(1, "TESTBENCH TIMEOUT (シミュレーションが終わらなかった)");
end

// ---------------------------------------------------------------
// 1 回の ADC 変換 + フレーム送出
// ---------------------------------------------------------------
//   enc    : ENCODE_ENABLE
//   dbg    : conv_encoder_state (1 でデバッグ固定データ)
//   addr   : ADDRESS ([5:0] が送信開始ディレイになる)
//   op_opt : OPERATE_OPT
//   op_ele : OPERATE_ELE
//   d_opt  : DATA_OPT
//   d_ele  : DATA_ELE
task send_frame(input enc, input dbg, input [7:0] addr,
                input op_opt, input op_ele,
                input [9:0] d_opt, input [9:0] d_ele);
    integer n;
begin
    ENCODE_ENABLE      = enc;
    conv_encoder_state = dbg;
    ADDRESS            = addr;
    OPERATE_OPT        = op_opt;
    OPERATE_ELE        = op_ele;
    DATA_OPT           = d_opt;
    DATA_ELE           = d_ele;

    // 期待値を確定させる
    exp_data   = dbg ? DEBUG_TEST_DATA : {d_opt, d_ele};
    exp_type   = {op_opt, op_ele};
    exp_enc_in = enc_input(addr, exp_type, exp_data);
    exp_enc_out= golden_encode(exp_enc_in);

    // 観測をクリア
    for (i = 0; i < 128; i = i + 1) out_at[i] = 1'bx;
    frame_seen    = 0;
    frame_timeout = 0;
    enable_width  = 0;
    comcon_peak   = 0;

    // ADC 変換中 (S_Bias = 1)
    repeat (5) @(posedge CLK);
    if (op_ele) S_Bias_ELE = 1'b1;
    if (op_opt) S_Bias_OPT = 1'b1;
    // OPERATE が両方 0 のときも変換だけは起きた体で S_Bias を振る
    if (!op_ele && !op_opt) begin
        S_Bias_ELE = 1'b1;
        S_Bias_OPT = 1'b1;
    end
    repeat (50) @(posedge CLK);

    // 変換終了 (ここが通信のトリガ)
    S_Bias_ELE   = 1'b0;
    S_Bias_OPT   = 1'b0;
    sbias_fall_t = $time;

    // ENABLE 立ち上がり待ち。ディレイぶん (ADDRESS[5:0] × 200clk) 余裕を見る
    n = 0;
    while ((com_enable !== 1'b1) && (n < 400 + addr[5:0] * DELAY_STEP)) begin
        @(posedge CLK);
        n = n + 1;
    end

    if (com_enable === 1'b1) begin
        frame_seen    = 1;
        enable_rise_t = $time;
        // ENABLE 立ち下がり待ち
        n = 0;
        while ((com_enable !== 1'b0) && (n < 2000)) begin
            @(posedge CLK);
            n = n + 1;
        end
        enable_width = n;
        if (com_enable !== 1'b0) frame_timeout = 1;
    end

    repeat (50) @(posedge CLK);
end
endtask

// ---------------------------------------------------------------
// 共通チェック
// ---------------------------------------------------------------

// フレームが正常に 1 回送出されたか
task check_frame_common;
begin
    `CHECK(frame_seen == 1,    "ADC 変換終了で送信が始まった (ENABLE が立った)")
    `CHECK(frame_timeout == 0, "送信が終了した (ENABLE が落ちた)")
    `CHECK(sel_state == 3'b000, "送信後に SELECT が none へ戻った")
    `CHECK(meas_code == exp_type, "MEASUREMENT_CODE が OPERATE と一致")

    // 送信開始ディレイ: ADDRESS[5:0] × 200clk
    $display("  (ADDRESS[5:0]=%0d 送信開始まで %0d ns / 期待 %0d ns 前後)",
             ADDRESS[5:0], enable_rise_t - sbias_fall_t,
             ADDRESS[5:0] * DELAY_STEP * clock);
    `CHECK((enable_rise_t - sbias_fall_t) >= ADDRESS[5:0] * DELAY_STEP * clock &&
           (enable_rise_t - sbias_fall_t) <= ADDRESS[5:0] * DELAY_STEP * clock + 10 * clock,
           "送信開始ディレイが ADDRESS[5:0] どおり")
end
endtask

// プリアンブル区間で OUT が 1bit ごとに反転しているか
task check_preamble;
begin
    preamble_bad = 0;
    for (i = PRE_LO + 1; i <= PRE_HI; i = i + 1)
        if (out_at[i] === out_at[i-1]) preamble_bad = preamble_bad + 1;
    `CHECK(preamble_bad == 0, "プリアンブル 32bit が 1bit ごとに反転している")
end
endtask

// ストップ区間が 3bit とも 1 か
task check_stop(input integer lo, input integer hi);
begin
    stop_bad = 0;
    for (i = lo; i <= hi; i = i + 1)
        if (out_at[i] !== 1'b1) stop_bad = stop_bad + 1;
    `CHECK(stop_bad == 0, "ストップビット 3bit がすべて 1")
end
endtask

// ---------------------------------------------------------------
// 検証タスク
// ---------------------------------------------------------------

// 符号化 OFF: ADDRESS / TYPE / DATA がそのまま載る
task expect_frame_off;
begin
    check_frame_common;
    `CHECK(comcon_peak >= STOP_OFF_HI, "非符号化フレーム長ぶん送信した (comcon >= 67)")

    check_preamble;

    for (i = 0; i < 8;  i = i + 1) got_addr[i] = out_at[ADDR_LO + i];
    $display("  (ADDRESS 期待 %b / 実測 %b)", ADDRESS, got_addr);
    `CHECK(got_addr === ADDRESS, "ADDRESS 8bit が LSB first で出力された")

    for (i = 0; i < 2;  i = i + 1) got_type[i] = out_at[TYPE_LO + i];
    $display("  (TYPE 期待 %b / 実測 %b)", exp_type, got_type);
    `CHECK(got_type === exp_type, "TYPE 2bit が OPERATE どおり出力された")

    for (i = 0; i < 20; i = i + 1) got_data[i] = out_at[DATA_LO + i];
    $display("  (DATA 期待 %05h / 実測 %05h)", exp_data, got_data);
    `CHECK(got_data === exp_data, "DATA 20bit が LSB first で出力された")

    check_stop(STOP_OFF_LO, STOP_OFF_HI);
end
endtask

// 符号化 ON: CONV_ENCODER の 64bit 出力が載る
task expect_frame_on;
begin
    check_frame_common;
    `CHECK(comcon_peak >= STOP_ON_HI, "符号化フレーム長ぶん送信した (comcon >= 101)")

    check_preamble;

    for (i = 0; i < 64; i = i + 1) got_enc[i] = out_at[ENC_LO + i];
    $display("  (符号化入力 %08h)", exp_enc_in);
    $display("  (符号化データ 期待 %016h / 実測 %016h)", exp_enc_out, got_enc);
    `CHECK(got_enc === exp_enc_out, "符号化データ 64bit が参照モデルと一致")

    // 符号化器が実際にその値を出しているか (DUT 内部との突き合わせ)
    `CHECK(COM_CON_OUT.COM_CON_TOP.encoder_input === exp_enc_in,
           "CONV_ENCODER への入力 32bit が期待どおり")
    `CHECK(COM_CON_OUT.COM_CON_TOP.encoder_output === exp_enc_out,
           "CONV_ENCODER の出力 64bit が参照モデルと一致")

    check_stop(STOP_ON_LO, STOP_ON_HI);
end
endtask

// OPERATE が両方 0 のときは送信しない
task expect_no_frame;
begin
    `CHECK(frame_seen == 0,        "OPERATE=00 では送信が始まらない")
    `CHECK(com_enable === 1'b0,    "ENABLE が立っていない")
    `CHECK(sel_state === 3'b000,   "SELECT が none のまま")
    `CHECK(meas_code === 2'b00,    "MEASUREMENT_CODE が 00")
end
endtask

endmodule
