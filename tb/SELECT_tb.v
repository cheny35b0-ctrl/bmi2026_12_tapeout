`timescale 1ns/1ns

//
// SELECT_tb.v - SELECT.v の状態遷移とシリアル出力のテストベンチ
//
// 検証内容
//   1. 符号化 OFF (ENCODE_ENABLE=0): counter -> address -> type -> shift -> stop -> fin
//   2. 符号化 ON  (ENCODE_ENABLE=1): counter -> encode -> stop -> fin
//   3. 各遷移が comcon_out の設計閾値ちょうどで起きること
//   4. OUT に載るビット列 (プリアンブル / ADDRESS / TYPE / ペイロード / ストップ)
//   5. ADC_STATE / ENABLE のディアサートで none に戻ること
//
// 注意: 以前の TB は SELECT の ENCODE_ENABLE を未接続 (floating) のままにしており、
//       符号化 ON パス (encode 状態) が一度も実行されていなかった。
//

module SELECT_tb;

parameter clock = 100;   // CLK 周期 [ns] (10MHz)

// SELECT.v と同じ状態エンコード
localparam ST_NONE    = 3'b000,
           ST_COUNTER = 3'b001,
           ST_ADDRESS = 3'b010,
           ST_TYPE    = 3'b011,
           ST_SHIFT   = 3'b100,
           ST_ENCODE  = 3'b101,
           ST_STOP    = 3'b110,
           ST_FIN     = 3'b111;

// OUT を comcon_out 値で読むときのフィールド位置
// (state が変わった次の CLK5 から OUT に反映されるため +1 されている)
localparam PREAMBLE_LO = 2,   PREAMBLE_HI = 34;   // スタートカウンタ
localparam ADDR_LO     = 35,  ADDR_HI     = 42;   // ADDRESS 8bit (LSB first)
localparam TYPE_LO     = 43,  TYPE_HI     = 44;   // TYPE 2bit    (LSB first)
localparam SHIFT_LO    = 45,  SHIFT_HI    = 64;   // 非符号化ペイロード 20bit
localparam STOP_OFF_LO = 65,  STOP_OFF_HI = 67;   // ストップ 3bit (符号化OFF)
localparam ENC_LO      = 35,  ENC_HI      = 98;   // 符号化ペイロード 64bit
localparam STOP_ON_LO  = 99,  STOP_ON_HI  = 101;  // ストップ 3bit (符号化ON)

reg CLK, POR, ADC_STATE, ENABLE;
reg ENCODE_ENABLE;
reg [1:0] TYPE;
reg [7:0] ADDRESS;
reg [63:0] payload;      // SHIFT_REG が流すつもりのデータ
wire OUT;
wire [2:0] state;

// ---------------------------------------------------------------
// CLK5 生成 (COM_ENABLE.v と同じ 2分周パルス)
// ---------------------------------------------------------------
wire [3:0] cnt2;
wire CLK5;
assign CLK5 = (cnt2 == 4'd1);
counter_4bit CLK5_divider(.CLK(CLK), .POR(POR), .RST(ADC_STATE),
                          .COUNT_UP(1'b1), .PERIOD(4'd2), .COUNT(cnt2));

// ---------------------------------------------------------------
// DUT
// ---------------------------------------------------------------
SELECT SELECT(
    .CLK(CLK),
    .CLK5(CLK5),
    .POR(POR),
    .ADC_STATE(ADC_STATE),
    .C_OUT1(C_OUT1),
    .S_OUT(S_OUT),
    .TYPE(TYPE),
    .ENABLE(ENABLE),
    .ADDRESS(ADDRESS),
    .ENCODE_ENABLE(ENCODE_ENABLE),   // 旧 TB では未接続だった
    .OUT(OUT),
    .state(state)
);

// CLOCK generation (10MHz, 100ns 周期)
always begin
    CLK = 1'b1;
    #50 CLK = 1'b0;
    #50;
end

// ---------------------------------------------------------------
// 周辺モジュールの代役
//   SELECT 単体を見るため COUNTER_COMCON / SHIFT_REG は繋がず、
//   同じタイミングで動く等価ロジックを TB 側に置く
// ---------------------------------------------------------------

// COUNTER_COMCON.v 相当: counter 状態で CLK5 ごとにトグルしてプリアンブルを作る
reg C_OUT1;
always @(posedge CLK or negedge POR) begin
    if (!POR)
        C_OUT1 <= 1'b0;
    else if ((state == ST_COUNTER) && (CLK5 == 1'b1))
        C_OUT1 <= !C_OUT1;
    else if (state != ST_COUNTER)
        C_OUT1 <= 1'b0;
end

// SHIFT_REG.v 相当: 既知のペイロードを LSB first で S_OUT に流す
reg S_OUT;
reg [63:0] tb_shift;
always @(posedge CLK or negedge POR) begin
    if (!POR)
        tb_shift <= 64'b0;
    else if (!ENABLE)
        tb_shift <= 64'b0;
    else if (!ENCODE_ENABLE && (state == ST_TYPE))
        tb_shift <= payload;                     // 符号化OFF: type 状態でロード
    else if (ENCODE_ENABLE && (state == ST_COUNTER))
        tb_shift <= payload;                     // 符号化ON : counter 状態でロード
    else if ((CLK5 == 1'b0) && ((state == ST_SHIFT) || (state == ST_ENCODE)))
        tb_shift <= tb_shift >> 1;
end

always @(posedge CLK or negedge POR) begin
    if (!POR)
        S_OUT <= 1'b0;
    else if (!ENABLE)
        S_OUT <= 1'b0;
    else if ((state == ST_COUNTER) || (state == ST_TYPE) ||
             (state == ST_SHIFT)   || (state == ST_ENCODE))
        S_OUT <= tb_shift[0];
end

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
integer timed_out;

// OUT を comcon_out 値ごとに保存する (CLK5 パルスの立ち上がりで採る)
//
// comcon_out は PERIOD=110 で折り返すため、ENABLE を長く保つと同じインデックスに
// フレーム末尾の値が上書きされる。各インデックス最初の 1 回だけ採る。
reg out_at [0:127];

always @(posedge CLK)
    if (CLK5 && ENABLE && (SELECT.comcon_out < 8'd128) && (out_at[SELECT.comcon_out] === 1'bx))
        out_at[SELECT.comcon_out] = OUT;

// 状態遷移の記録
integer   nseq;
reg [2:0] seq_state  [0:15];
integer   seq_comcon [0:15];
reg [2:0] prev_state;

always @(posedge CLK) begin
    if (state !== prev_state) begin
        if (nseq < 16) begin
            seq_state[nseq]  = state;
            seq_comcon[nseq] = SELECT.comcon_out;
            nseq = nseq + 1;
        end
        prev_state = state;
    end
end

// 復元したフィールド
reg [7:0]  got_addr;
reg [1:0]  got_type;
reg [19:0] got_pay20;
reg [63:0] got_pay64;
integer    preamble_bad;
integer    stop_bad;

// ---------------------------------------------------------------
// メインシーケンス
// ---------------------------------------------------------------
initial begin
    $dumpfile("SELECT_tb.vcd");
    $dumpvars(0, SELECT_tb);

    $display("========================================");
    $display("SELECT Testbench");
    $display("========================================");

    POR           = 1'b0;
    ADC_STATE     = 1'b1;
    ENABLE        = 1'b0;
    ENCODE_ENABLE = 1'b0;
    ADDRESS       = 8'b1010_0110;
    TYPE          = 2'b10;
    payload       = 64'b0;
    prev_state    = ST_NONE;
    nseq          = 0;

    #300 POR = 1'b1;

    // ============ 1. 符号化 OFF ============
    $display("\n----------------------------------------");
    $display(" 1. 符号化 OFF (ENCODE_ENABLE = 0)");
    $display("----------------------------------------");
    ADDRESS = 8'b1010_0110;
    TYPE    = 2'b10;
    run_frame(1'b0, 64'h0000_0000_000A_5C3B);   // 下位20bit = 20'hA5C3B
    expect_frame_off;

    // ============ 2. 符号化 ON ============
    $display("\n----------------------------------------");
    $display(" 2. 符号化 ON (ENCODE_ENABLE = 1)");
    $display("----------------------------------------");
    ADDRESS = 8'b0010_1100;
    TYPE    = 2'b11;
    run_frame(1'b1, 64'h396F_A11C_D2B3_7DC0);   // CONV_ENCODER の 0x12345678 符号化結果
    expect_frame_on;

    // ============ 3. 符号化 OFF をもう一度 ============
    // 前フレームの残留 (P_ADDRESS / shift_reg) で 2 回目が崩れないかの回帰
    $display("\n----------------------------------------");
    $display(" 3. 符号化 OFF に戻して再送");
    $display("----------------------------------------");
    ADDRESS = 8'b0101_1001;
    TYPE    = 2'b01;
    run_frame(1'b0, 64'h0000_0000_0005_A3C7);   // 下位20bit = 20'h5A3C7
    expect_frame_off;

    // ============ 4. 中断動作 ============
    $display("\n----------------------------------------");
    $display(" 4. ADC_STATE / ENABLE による中断");
    $display("----------------------------------------");
    expect_abort;

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
    #2000000;
    $fatal(1, "TESTBENCH TIMEOUT (シミュレーションが終わらなかった)");
end

// ---------------------------------------------------------------
// 1 フレーム送出
// ---------------------------------------------------------------
task run_frame(input enc, input [63:0] pay);
    integer n;
begin
    ENCODE_ENABLE = enc;
    payload       = pay;

    // 観測をクリア
    for (i = 0; i < 128; i = i + 1) out_at[i] = 1'bx;
    nseq       = 0;
    prev_state = state;
    timed_out  = 0;

    // ADC 変換中 (通信停止) から始める
    ADC_STATE = 1'b1;
    ENABLE    = 1'b0;
    repeat (5) @(posedge CLK);
    ADC_STATE = 1'b0;
    repeat (5) @(posedge CLK);

    // 通信開始
    ENABLE = 1'b1;

    // fin に入るまで待つ (ハングしても抜けられるよう上限つき)
    n = 0;
    while ((state !== ST_FIN) && (n < 4000)) begin
        @(posedge CLK);
        n = n + 1;
    end
    if (state !== ST_FIN) timed_out = 1;

    repeat (4) @(posedge CLK);
    ENABLE = 1'b0;
    repeat (4) @(posedge CLK);
end
endtask

// ---------------------------------------------------------------
// 検証タスク
// ---------------------------------------------------------------

// プリアンブル区間で OUT が 1bit ごとに反転しているか
task check_preamble;
begin
    preamble_bad = 0;
    for (i = PREAMBLE_LO + 1; i <= PREAMBLE_HI; i = i + 1)
        if (out_at[i] === out_at[i-1]) preamble_bad = preamble_bad + 1;
    `CHECK(preamble_bad == 0, "プリアンブルが 1bit ごとに反転している")
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

// 符号化 OFF: counter -> address -> type -> shift -> stop -> fin
task expect_frame_off;
begin
    `CHECK(timed_out == 0, "fin まで到達した (ハングしていない)")

    // --- 状態遷移 ---
    // 6 回の前進 + ENABLE を落とした後の fin -> none で計 7 回
    `CHECK(nseq == 7, "状態遷移が 7 回 (counter/address/type/shift/stop/fin/none)")
    `CHECK(seq_state[0] == ST_COUNTER && seq_comcon[0] == 1,  "none -> counter (comcon=1)")
    `CHECK(seq_state[1] == ST_ADDRESS && seq_comcon[1] == 34, "counter -> address (comcon=34)")
    `CHECK(seq_state[2] == ST_TYPE    && seq_comcon[2] == 42, "address -> type (comcon=42)")
    `CHECK(seq_state[3] == ST_SHIFT   && seq_comcon[3] == 44, "type -> shift (comcon=44)")
    `CHECK(seq_state[4] == ST_STOP    && seq_comcon[4] == 64, "shift -> stop (comcon=64)")
    `CHECK(seq_state[5] == ST_FIN     && seq_comcon[5] == 67, "stop -> fin (comcon=67)")
    `CHECK(seq_state[6] == ST_NONE,                           "ENABLE=0 で fin -> none に戻った")

    // --- 出力ビット列 ---
    check_preamble;

    for (i = 0; i < 8; i = i + 1) got_addr[i] = out_at[ADDR_LO + i];
    $display("  (ADDRESS 期待 %b / 実測 %b)", ADDRESS, got_addr);
    `CHECK(got_addr === ADDRESS, "ADDRESS 8bit が LSB first で出力された")

    for (i = 0; i < 2; i = i + 1) got_type[i] = out_at[TYPE_LO + i];
    $display("  (TYPE 期待 %b / 実測 %b)", TYPE, got_type);
    `CHECK(got_type === TYPE, "TYPE 2bit が LSB first で出力された")

    for (i = 0; i < 20; i = i + 1) got_pay20[i] = out_at[SHIFT_LO + i];
    $display("  (ペイロード 期待 %05h / 実測 %05h)", payload[19:0], got_pay20);
    `CHECK(got_pay20 === payload[19:0], "ペイロード 20bit が LSB first で出力された")

    check_stop(STOP_OFF_LO, STOP_OFF_HI);
    `CHECK(out_at[STOP_OFF_HI + 1] !== 1'b1, "fin に入って OUT が 1 でなくなった")
end
endtask

// 符号化 ON: counter -> encode -> stop -> fin
task expect_frame_on;
begin
    `CHECK(timed_out == 0, "fin まで到達した (ハングしていない)")

    // --- 状態遷移 ---
    // 4 回の前進 + ENABLE を落とした後の fin -> none で計 5 回
    `CHECK(nseq == 5, "状態遷移が 5 回 (counter/encode/stop/fin/none)")
    `CHECK(seq_state[0] == ST_COUNTER && seq_comcon[0] == 1,   "none -> counter (comcon=1)")
    `CHECK(seq_state[1] == ST_ENCODE  && seq_comcon[1] == 34,  "counter -> encode (comcon=34)")
    `CHECK(seq_state[2] == ST_STOP    && seq_comcon[2] == 98,  "encode -> stop (comcon=98)")
    `CHECK(seq_state[3] == ST_FIN     && seq_comcon[3] == 101, "stop -> fin (comcon=101)")
    `CHECK(seq_state[4] == ST_NONE,                            "ENABLE=0 で fin -> none に戻った")

    // 符号化 ON では address / type / shift を通ってはいけない
    stop_bad = 0;
    for (i = 0; i < nseq; i = i + 1)
        if (seq_state[i] == ST_ADDRESS || seq_state[i] == ST_TYPE || seq_state[i] == ST_SHIFT)
            stop_bad = stop_bad + 1;
    `CHECK(stop_bad == 0, "符号化 ON では address/type/shift を経由しない")

    // --- 出力ビット列 ---
    check_preamble;

    for (i = 0; i < 64; i = i + 1) got_pay64[i] = out_at[ENC_LO + i];
    $display("  (符号化データ 期待 %016h / 実測 %016h)", payload, got_pay64);
    `CHECK(got_pay64 === payload, "符号化データ 64bit が LSB first で出力された")

    check_stop(STOP_ON_LO, STOP_ON_HI);
    `CHECK(out_at[STOP_ON_HI + 1] !== 1'b1, "fin に入って OUT が 1 でなくなった")
end
endtask

// 中断: ADC_STATE / ENABLE で none に戻るか
task expect_abort;
    integer n;
begin
    // --- ENABLE=0 で中断 ---
    ENCODE_ENABLE = 1'b0;
    ADC_STATE     = 1'b1;
    ENABLE        = 1'b0;
    repeat (5) @(posedge CLK);
    ADC_STATE     = 1'b0;
    repeat (5) @(posedge CLK);
    ENABLE        = 1'b1;

    // address 状態まで進める
    n = 0;
    while ((state !== ST_ADDRESS) && (n < 4000)) begin
        @(posedge CLK);
        n = n + 1;
    end
    `CHECK(state === ST_ADDRESS, "中断テスト用に address 状態まで進んだ")

    ENABLE = 1'b0;
    @(posedge CLK);
    @(posedge CLK);
    `CHECK(state === ST_NONE, "ENABLE=0 で none に戻った")
    `CHECK(OUT === 1'b0,      "ENABLE=0 で OUT が 0 になった")

    // --- ADC_STATE=1 で中断 ---
    ADC_STATE = 1'b1;
    repeat (5) @(posedge CLK);
    ADC_STATE = 1'b0;
    repeat (5) @(posedge CLK);
    ENABLE    = 1'b1;

    n = 0;
    while ((state !== ST_COUNTER) && (n < 4000)) begin
        @(posedge CLK);
        n = n + 1;
    end
    `CHECK(state === ST_COUNTER, "中断テスト用に counter 状態まで進んだ")

    ADC_STATE = 1'b1;      // 次の ADC 変換が始まった
    @(posedge CLK);
    @(posedge CLK);
    `CHECK(state === ST_NONE, "ADC_STATE=1 で none に戻った")

    ENABLE    = 1'b0;
    ADC_STATE = 1'b0;
    repeat (5) @(posedge CLK);
end
endtask

endmodule
