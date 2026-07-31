// CONV_ENCODER_TB.v - Testbench for Convolutional Encoder
// 畳み込み符号化器テストベンチ (セルフチェック版)
//
// 検証内容:
//   - 64bit 符号化結果を参照モデル (K=3, rate 1/2, G0=7(111), G1=5(101)) と突き合わせる
//   - ゼロ終端で符号化器の内部状態が 2'b00 に戻ること
//   - START から ENCODE_DONE までのレイテンシが一定であること
//   - 符号化完了後に DATA_OUT が保持されること
//   - POR で内部状態と出力がクリアされること
//
// ■ START の与え方について (重要)
//   CONV_ENCODER.v はビットカウンタの RST に `counter_rst || START == 1'b0` を使っている。
//   つまり START はレベル信号であり、符号化中はずっと High に保つ必要がある。
//   1 クロックだけパルスを出すとカウンタが 0 に固定されて ENCODE_DONE が永久に立たない。
//   実際の接続元である COM_CON_TOP.v も
//       assign encoder_start = (state_comcon == 3'b001) && ENCODE_ENABLE;
//   というレベル信号で駆動しているため、この TB もレベル駆動に合わせている。
//
//   また ENCODE_DONE は次の符号化が始まるまで High のまま保持される。
//   そのため完了待ちは「DONE が Low に落ちる (符号化開始) のを待ってから High を待つ」
//   という 2 段構えにしないと、前回の完了フラグを拾って即座に抜けてしまう。

`timescale 1ns/1ns

module CONV_ENCODER_TB;

// パラメータ定義
parameter clock = 100;  // 100nsクロック周期（10MHz）
// DUT 入力を駆動するタイミング (クロック立ち上がりからのオフセット)。
// 0 にすると TB のブロッキング代入と DUT の posedge サンプリングが同時刻になり、
// START の新旧どちらを拾うかがレースになって符号化レイテンシが 1clk ぶれる。
// 半周期 (50ns) より十分手前で駆動する。
parameter delay = 10;

// START 立ち上がりから ENCODE_DONE までの期待クロック数。
// 34 と 35 の 2 通りがあり、どちらも正常。
//   - POR 後の初回だけ 35clk。CONV_ENCODER の count_up は POR 直後だけ 0 で、
//     start 分岐が発火した edge ではまだ 0 のため bit_counter がその 1clk は進まない。
//   - 2 回目以降は 34clk。count_up が前回の符号化から 1 のまま残っているので、
//     start 分岐が発火した edge で bit_counter が同時に 0→1 へ進む。
localparam DONE_CLK_MIN = 34;
localparam DONE_CLK_MAX = 35;

// 完了待ちの上限クロック数。これを超えたらハングとみなして FAIL にする
localparam WAIT_LIMIT = 200;

// COM_CON_TOP 側の予算: state=counter は comcon_out が 34 に達するまで続き、
// comcon_out は CLK5 (2CLK に 1 回) で進むので約 68CLK ある。
// EXPECT_DONE_CLK がこれを超えると統合時に符号化が間に合わなくなる。
localparam ENCODE_BUDGET_CLK = 68;

// テスト信号
// 入力 : reg
// 出力 : wire
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

// ---------------------------------------------------------------
// セルフチェック
// ---------------------------------------------------------------
integer checks = 0;   // 実行したチェック数
integer errors = 0;   // 失敗したチェック数

// run_case が結果を書き込む観測値
reg [63:0] got;          // RTL の符号化結果
reg [63:0] exp;          // 参照モデルの期待値
reg [1:0]  fin_state;    // 符号化完了時点の内部状態
integer    done_clk;     // START から ENCODE_DONE までのクロック数
reg        hung;         // WAIT_LIMIT を超えた

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

// ---------------------------------------------------------------
// 参照モデル
// ---------------------------------------------------------------

// 仕様通りの畳み込み符号化器 (K=3, rate 1/2, G0=111, G1=101)
//   - 入力は MSB first (DATA_IN[31] から処理)
//   - 各入力ビットに対し c0 を先、c1 を後に出力
//   - k 番目の入力ビットの出力は encoded[k*2] = c0, encoded[k*2+1] = c1
function [63:0] golden_encode(input [31:0] d);
    integer k;
    reg s0, s1, b;
begin
    s0 = 1'b0;              // S0
    s1 = 1'b0;              // S1
    golden_encode = 64'b0;
    for (k = 0; k < 32; k = k + 1) begin
        b = d[31 - k];
        golden_encode[k*2]     = b ^ s0 ^ s1;   // G0 = 111
        golden_encode[k*2 + 1] = b ^ s1;        // G1 = 101
        s1 = s0;                                 // シフト
        s0 = b;
    end
end
endfunction

// COM_CON_TOP.v の encoder_input と同じ並びで 32bit 入力を組み立てる。
// 各フィールドはビット順が反転されて詰められる点に注意 (COM_CON_TOP.v:34-38)。
function [31:0] pack_frame(input [7:0] addr, input [1:0] mtype, input [19:0] data);
begin
    pack_frame = {addr[0], addr[1], addr[2], addr[3],
                  addr[4], addr[5], addr[6], addr[7],
                  mtype[0], mtype[1],
                  data[0],  data[1],  data[2],  data[3],  data[4],
                  data[5],  data[6],  data[7],  data[8],  data[9],
                  data[10], data[11], data[12], data[13], data[14],
                  data[15], data[16], data[17], data[18], data[19],
                  2'b00};
end
endfunction

// ---------------------------------------------------------------
// 符号化を 1 回実行して結果を got / fin_state / done_clk に取り込む
// ---------------------------------------------------------------
task run_case(input [31:0] d);
    integer n;
begin
    exp  = golden_encode(d);
    hung = 1'b0;

    // START を一度落としてビットカウンタを 0 に戻す (RTL は START=0 をカウンタ RST に使う)
    @(posedge CLK) #delay START = 1'b0;
    @(posedge CLK) #delay; DATA_IN = d; START = 1'b1;

    // 前回の ENCODE_DONE が残っているので、まず Low (符号化開始) を待つ
    n = 0;
    while ((ENCODE_DONE === 1'b1) && (n < WAIT_LIMIT)) begin
        @(posedge CLK) #delay;
        n = n + 1;
    end
    // 完了 (High) を待つ
    while ((ENCODE_DONE !== 1'b1) && (n < WAIT_LIMIT)) begin
        @(posedge CLK) #delay;
        n = n + 1;
    end

    done_clk = n;
    if (ENCODE_DONE !== 1'b1) hung = 1'b1;

    got       = DATA_OUT;
    fin_state = uut.state;
end
endtask

// 1 ベクタ分の共通チェック (ゼロ終端された入力用)
task check_case(input [31:0] d);
begin
    run_case(d);
    $display("  IN=%08h  RTL=%016h  EXP=%016h  state=%b  %0d clk",
             d, got, exp, fin_state, done_clk);
    `CHECK(hung == 1'b0,       "ENCODE_DONE が返ってきた (ハングなし)")
    `CHECK(got === exp,        "64bit 符号化結果が参照モデルと一致")
    `CHECK(fin_state == 2'b00, "ゼロ終端で内部状態が 00 に戻った")
    `CHECK(done_clk >= DONE_CLK_MIN && done_clk <= DONE_CLK_MAX,
           "符号化レイテンシが想定範囲 (34-35clk) に収まる")
end
endtask

// ---------------------------------------------------------------
// テストシーケンス
// ---------------------------------------------------------------
reg [63:0] held;
integer    prev_done_clk;

initial begin
    $display("========================================");
    $display("CONV_ENCODER Testbench");
    $display("========================================");

    // 初期化
    POR = 1'b0;
    START = 1'b0;
    DATA_IN = 32'h00000000;

    // パワーオンリセット解除
    #200;
    @(posedge CLK) #delay POR = 1'b1;
    $display("[%0t ns] POR released", $time);

    `CHECK(DATA_OUT === 64'b0,     "POR 直後は DATA_OUT が 0")
    `CHECK(ENCODE_DONE === 1'b0,   "POR 直後は ENCODE_DONE が 0")

    // ---------------------------------------------------------------
    // ゼロ終端済みベクタ (下位 2bit = 00) の符号化結果を検証する
    // ---------------------------------------------------------------
    $display("\n--- Case 1: 全ビット 0 ---");
    check_case(32'h00000000);
    `CHECK(got === 64'b0, "全 0 入力の符号化結果は全 0")

    $display("\n--- Case 2: 全ビット 1 (ゼロ終端) ---");
    check_case(32'h3FFFFFFC);

    $display("\n--- Case 3: 交互パターン 1010... (ゼロ終端) ---");
    check_case(32'hAAAAAAA8);

    $display("\n--- Case 4: 交互パターン 0101... (ゼロ終端) ---");
    check_case(32'h55555554);

    $display("\n--- Case 5: MSB のみ 1 (インパルス応答) ---");
    check_case(32'h80000000);
    // d[0]=1 のみ → c0,c1 = 1,1 / 次段 1,0 / 次段 1,1 の順に出て以降 0
    // encoded[1:0]=2'b11, encoded[3:2]=2'b01, encoded[5:4]=2'b11
    `CHECK(got[5:0] === 6'b11_01_11, "インパルス応答が G=(7,5) のパターンと一致")
    `CHECK(got[63:6] === 58'b0,      "インパルス応答は 3 シンボルで収束する")

    $display("\n--- Case 6: ランダム 0x12345678 ---");
    check_case(32'h12345678);

    $display("\n--- Case 7: ランダム 0xDEADBEEC (ゼロ終端) ---");
    check_case(32'hDEADBEEC);

    $display("\n--- Case 8: 実フレーム相当 (ADDR=0x2C TYPE=11 DATA=0x7B3A9) ---");
    // COM_CON_TOP が CONV_ENCODER へ渡すのと同じ並びの 32bit
    check_case(pack_frame(8'h2c, 2'b11, 20'h7B3A9));

    // ---------------------------------------------------------------
    // 符号化レイテンシが統合時の予算に収まっているか
    // ---------------------------------------------------------------
    $display("\n--- レイテンシ予算 ---");
    $display("  実測 %0d clk / 予算 %0d clk (COM_CON_TOP の state=counter 期間)",
             done_clk, ENCODE_BUDGET_CLK);
    `CHECK(done_clk <= ENCODE_BUDGET_CLK, "符号化が state=counter の期間内に完了する")

    // ---------------------------------------------------------------
    // ゼロ終端の契約: 終端 2bit が 0 でないと状態が 00 に戻らない
    // ---------------------------------------------------------------
    $display("\n--- Case 9: 終端 2bit が 0 でない入力 (契約違反の確認) ---");
    run_case(32'hFFFFFFFF);
    $display("  IN=%08h  RTL=%016h  EXP=%016h  state=%b",
             32'hFFFFFFFF, got, exp, fin_state);
    `CHECK(got === exp,        "終端なし入力でも符号化結果自体は参照モデルと一致")
    `CHECK(fin_state != 2'b00, "終端 2bit が 0 でないと状態は 00 に戻らない")

    // ---------------------------------------------------------------
    // 符号化完了後の保持
    // ---------------------------------------------------------------
    $display("\n--- 完了後の DATA_OUT 保持 ---");
    check_case(32'h12345678);
    held = got;
    @(posedge CLK) #delay START = 1'b0;
    repeat (20) @(posedge CLK);
    `CHECK(DATA_OUT === held, "START を落としても DATA_OUT が保持される")

    // ---------------------------------------------------------------
    // 連続実行: 同じ入力を 2 回続けて同じ結果になるか
    // ---------------------------------------------------------------
    $display("\n--- 連続実行の再現性 ---");
    check_case(32'hDEADBEEC);
    held          = got;
    prev_done_clk = done_clk;
    check_case(32'hDEADBEEC);
    `CHECK(got === held,               "同じ入力を再実行すると同じ結果になる")
    `CHECK(done_clk == prev_done_clk,  "連続実行で符号化レイテンシがぶれない")

    // ---------------------------------------------------------------
    // POR による初期化
    // ---------------------------------------------------------------
    $display("\n--- 符号化中の POR ---");
    @(posedge CLK) #delay START = 1'b0;
    @(posedge CLK) #delay; DATA_IN = 32'hDEADBEEC; START = 1'b1;
    repeat (10) @(posedge CLK);      // 符号化の途中
    @(posedge CLK) #delay POR = 1'b0;
    @(posedge CLK) #delay;
    `CHECK(DATA_OUT === 64'b0,   "POR で DATA_OUT がクリアされる")
    `CHECK(ENCODE_DONE === 1'b0, "POR で ENCODE_DONE がクリアされる")
    `CHECK(uut.state === 2'b00,  "POR で内部状態がクリアされる")

    @(posedge CLK) #delay POR = 1'b1;
    // POR 解除後にもう一度正しく符号化できるか
    check_case(32'hDEADBEEC);

    // ---------------------------------------------------------------
    // 結果サマリ
    // ---------------------------------------------------------------
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

// タイムアウト監視（100us後に強制終了）
// $finish だと終了コード 0 になり CI が PASS と誤判定するため $fatal を使う
initial begin
    #1000000;
    $fatal(1, "TESTBENCH TIMEOUT (シミュレーションが完了しませんでした)");
end

// 波形ダンプ（オプション）
initial begin
    $dumpfile("conv_encoder_tb.vcd");
    $dumpvars(0, CONV_ENCODER_TB);
end

endmodule
