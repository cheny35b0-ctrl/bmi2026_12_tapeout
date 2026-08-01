`timescale 1ns/1ns

module TOP_202512TO_tb;

parameter delay = 0;
parameter clock = 100;
parameter MSEC  = 1000000;   // 1ms を ns で表した値 (10MHz × 10000 カウント)

// 測定待ち時間と、その間に走る測定サイクル数
// MEASURE.v の MSEC カウンタ (PERIOD=10000) が 10MHz で 1ms を刻み、
// 起動直後に 1 回 + 1ms ごとに 1 回 ADC が起動する
parameter  MEAS_WAIT     = 2500000;                   // 測定待ち [ns]
parameter  MEAS_INTERVAL = 1000000;                   // 測定間隔 [ns] (10000clk × 100ns)
// TOP で MEASURE の RST を OPERATE 連動にしているため、起動のたびに msec_count が
// 0 から始まり、測定回数は毎回一定になる (起動直後の 1 回 + 1ms ごと)
localparam EXPECT_MEAS   = MEAS_WAIT / MEAS_INTERVAL + 1; // = 3

// 刺激待ち時間。電気刺激N の DELAY が 6ms なので、P/N 両方の発火を
// 観測するにはそれを超える必要がある
parameter  STIM_WAIT     = 8000000;                   // [ns]
// 8 周目の定量検証用。PERIOD=3ms × LOOP=3 + DELAY=1ms で 10ms あれば足りる
parameter  STIM_TIMING_WAIT = 10000000;               // [ns]
// build_command が設定する電気刺激P の DELAY (16'h0001 = 1ms)
parameter  ELE_P_DELAY   = 1000000;                   // [ns]

// Clock and reset
reg CLK;
reg POR;
reg ORDER;

// Address inputs
reg [1:0] unique_low;
reg unique_debug;

// Manchester decoder
wire MAN;
reg DECODER_RST;
wire CLK_OUT;
wire ORDER_OUT;

// Electric stimulation
wire P_STIM_EN;
wire N_STIM_EN;
wire [4:0] P_STIM;
wire [4:0] N_STIM;

// Optical stimulation
wire [4:0] OPT_STIM;

// Electric measuring
reg COMPARATOR_ELE;
wire S_Bias_ELE;
wire COMP_CLK_ELE;
wire S1_ELE;
wire [9:0] S2_ELE;
wire S2_dummy_ELE;
wire S3_ELE;
wire [4:0] CAL1_ELE, CAL2_ELE;

// Optical measuring
reg COMPARATOR_OPT;
wire S_Bias_OPT;
wire COMP_CLK_OPT;
wire S1_OPT;
wire [9:0] S2_OPT;
wire S2_dummy_OPT;
wire S3_OPT;
wire [4:0] CAL1_OPT, CAL2_OPT;

// Convolutional encoding debug
reg conv_encoder_state;
reg ENCODE_ENABLE_ext;

// Communication control
wire SERIAL_OUT;
// 短コマンド用 reg
reg [19:0] trig_cmd;

// Command register
reg [399:0] command = 400'b0;

// Instantiate DUT
TOP_202512TO dut (
    .CLK(CLK),
    .ORDER(ORDER),
    .POR(POR),
    .unique_low(unique_low),
    .unique_debug(unique_debug),
    .MAN(MAN),
    .DECODER_RST(DECODER_RST),
    .CLK_OUT(CLK_OUT),
    .ORDER_OUT(ORDER_OUT),
    .P_STIM_EN(P_STIM_EN),
    .N_STIM_EN(N_STIM_EN),
    .P_STIM(P_STIM),
    .N_STIM(N_STIM),
    .OPT_STIM(OPT_STIM),
    .COMPARATOR_ELE(COMPARATOR_ELE),
    .S_Bias_ELE(S_Bias_ELE),
    .COMP_CLK_ELE(COMP_CLK_ELE),
    .S1_ELE(S1_ELE),
    .S2_ELE(S2_ELE),
    .S2_dummy_ELE(S2_dummy_ELE),
    .S3_ELE(S3_ELE),
    .CAL1_ELE(CAL1_ELE),
    .CAL2_ELE(CAL2_ELE),
    .COMPARATOR_OPT(COMPARATOR_OPT),
    .S_Bias_OPT(S_Bias_OPT),
    .COMP_CLK_OPT(COMP_CLK_OPT),
    .S1_OPT(S1_OPT),
    .S2_OPT(S2_OPT),
    .S2_dummy_OPT(S2_dummy_OPT),
    .S3_OPT(S3_OPT),
    .CAL1_OPT(CAL1_OPT),
    .CAL2_OPT(CAL2_OPT),
    .conv_encoder_state(conv_encoder_state),
    .ENCODE_ENABLE_ext(ENCODE_ENABLE_ext),
    .SERIAL_OUT(SERIAL_OUT)
);

// CLOCK generation (10MHz, 100ns 周期)
always begin
    CLK = 1'b1;
    #50 CLK = 1'b0;
    #50;
end

// Manchester encoding
assign MAN = (CLK ^| ORDER);

integer J;

// ---------------------------------------------------------------
// ADC コードの注入
// ---------------------------------------------------------------
// ADC_logic は SAR 型で、phase 4〜13 の間に
//     DATA[13 - phase] <= COMPARATOR
// と 1bit ずつ確定させる。TB 側で phase に応じた COMPARATOR を返すことで
// 任意の 10bit 変換結果を作れる。
// これにより「コンパレータ → ADC → DATA → シリアル出力」まで一気通貫で検証できる。
// (以前は COMPARATOR を 0 固定にしていたため、この経路が検証できていなかった)
reg [9:0] adc_code_ele;
reg [9:0] adc_code_opt;

// 自機アドレス。TOP_202512TO.v の unique 生成と同じ式を TB 側で独立に書いている
wire [7:0] unique_addr = {2'b00, unique_debug ? 4'b1011 : 4'b0000, unique_low};

// アドレス不一致テスト用に送信前の command を退避する
reg [399:0] cmd_before;

wire [7:0] ph_ele = dut.ELECTRIC_MEAS.ADC_logic.phase;
wire [7:0] ph_opt = dut.OPTICAL_MEAS.ADC_logic.phase;

always @(*) begin
    if ((ph_ele >= 8'd4) && (ph_ele <= 8'd13))
        COMPARATOR_ELE = adc_code_ele[8'd13 - ph_ele];
    else
        COMPARATOR_ELE = 1'b0;
end

always @(*) begin
    if ((ph_opt >= 8'd4) && (ph_opt <= 8'd13))
        COMPARATOR_OPT = adc_code_opt[8'd13 - ph_opt];
    else
        COMPARATOR_OPT = 1'b0;
end

// ---------------------------------------------------------------
// SERIAL_OUT のフレーム取り込み
// ---------------------------------------------------------------
// COM_CON_OUT_tb と同じ方式で、送信中の comcon_out 値をインデックスにして
// SERIAL_OUT を並べ直す。
wire [2:0] ser_state  = dut.COM_CON_OUT.COM_CON_TOP.SELECT.state;
wire [7:0] ser_comcon = dut.COM_CON_OUT.COM_CON_TOP.SELECT.comcon_out;
wire       ser_enable = dut.COM_CON_OUT.COM_CON_TOP.ENABLE;
wire       ser_clk5   = dut.COM_CON_OUT.COM_CON_TOP.CLK5;

// OUT を comcon_out 値で読むときのフィールド位置
localparam F_PRE_LO  = 2,   F_PRE_HI  = 34;   // スタートカウンタ
localparam F_ADDR_LO = 35,  F_ADDR_HI = 42;   // ADDRESS 8bit (LSB first)
localparam F_TYPE_LO = 43,  F_TYPE_HI = 44;   // TYPE 2bit    (LSB first)
localparam F_DATA_LO = 45,  F_DATA_HI = 64;   // DATA 20bit   (LSB first)
localparam F_SOFF_LO = 65,  F_SOFF_HI = 67;   // ストップ 3bit (符号化OFF)
localparam F_ENC_LO  = 35,  F_ENC_HI  = 98;   // 符号化データ 64bit
localparam F_SON_LO  = 99,  F_SON_HI  = 101;  // ストップ 3bit (符号化ON)

localparam [19:0] DEBUG_TEST_DATA = 20'h7B3A9;   // COM_CON_OUT.v の localparam と同じ

// ENABLE はフレーム送出後も続き comcon_out が折り返すため、
// 各インデックス最初の 1 回だけ採る (末尾の 0 で先頭が潰れるのを防ぐ)
reg out_at [0:127];
integer ci;

always @(posedge CLK)
    if (ser_clk5 && ser_enable && (ser_comcon < 8'd128) && (out_at[ser_comcon] === 1'bx))
        out_at[ser_comcon] = SERIAL_OUT;

// ---------------------------------------------------------------
// セルフチェック
// ---------------------------------------------------------------
integer checks = 0;   // 実行したチェック数
integer errors = 0;   // 失敗したチェック数

// 周回ごとにリセットする観測値
integer com_peak         = 0;  // 送信中に COMMAND.com が到達した最大値
integer sbias_ele_count  = 0;  // 電気測定サイクル数
integer sbias_opt_count  = 0;  // 光測定サイクル数
integer serial_toggles   = 0;  // SERIAL_OUT の変化回数
integer p_stim_en_count  = 0;  // 電気刺激P の発火回数
integer n_stim_en_count  = 0;  // 電気刺激N の発火回数
integer opt_stim_toggles = 0;  // 光刺激出力の変化回数

// 測定間隔の検証用
time    sbias_ele_prev   = 0;
time    sbias_opt_prev   = 0;
integer sbias_ele_bad_gap = 0; // 間隔が MEAS_INTERVAL でなかった回数
integer sbias_opt_bad_gap = 0;

// 刺激 DELAY の検証用: OPERATE が立ってから P_STIM_EN が出るまでの実測時間
time    stim_op_start    = 0;
integer p_stim_delay     = 0;

// 刺激パルスの幅・周期の実測用
time    p_stim_rise_t    = 0;   // 直近の立ち上がり時刻
integer p_stim_width     = 0;   // 1 発目のパルス幅 [ns]
integer p_stim_period    = 0;   // 1 発目→2 発目の間隔 [ns]

// build_command が組み立てた値。expect_full_command が期待値として参照する
reg [7:0]  exp_addr;
reg [7:0]  exp_enable;
reg [15:0] exp_ele_p_period;
reg [15:0] exp_ele_p_width;
reg [15:0] exp_ele_p_loop;
reg [15:0] exp_ele_p_delay;
reg        exp_encode_bit;   // command[343]

// 1 フレーム分の期待値と復元値
reg        exp_encode_on;    // command[343] | ENCODE_ENABLE_ext
reg [19:0] exp_frame_data;
reg [1:0]  exp_frame_type;
reg [31:0] exp_frame_enc_in;
reg [63:0] exp_frame_enc_out;
reg [7:0]  got_frame_addr;
reg [1:0]  got_frame_type;
reg [19:0] got_frame_data;
reg [63:0] got_frame_enc;
integer    frame_seen;
integer    frame_preamble_bad;
integer    frame_stop_bad;

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

always @(posedge CLK)
    if (dut.COMMAND.com > com_peak) com_peak = dut.COMMAND.com;

always @(posedge S_Bias_ELE) begin
    sbias_ele_count = sbias_ele_count + 1;
    if (sbias_ele_prev != 0 && ($time - sbias_ele_prev) != MEAS_INTERVAL)
        sbias_ele_bad_gap = sbias_ele_bad_gap + 1;
    sbias_ele_prev = $time;
end

always @(posedge S_Bias_OPT) begin
    sbias_opt_count = sbias_opt_count + 1;
    if (sbias_opt_prev != 0 && ($time - sbias_opt_prev) != MEAS_INTERVAL)
        sbias_opt_bad_gap = sbias_opt_bad_gap + 1;
    sbias_opt_prev = $time;
end

always @(SERIAL_OUT)     serial_toggles = serial_toggles + 1;
always @(posedge N_STIM_EN) n_stim_en_count = n_stim_en_count + 1;
always @(OPT_STIM)          opt_stim_toggles = opt_stim_toggles + 1;

// 刺激の起動時刻と、そこから最初の P_STIM_EN までの遅延を測る
always @(posedge dut.ELE_P_STIM.OPERATE) stim_op_start = $time;

always @(posedge P_STIM_EN) begin
    if (p_stim_en_count == 0 && stim_op_start != 0)
        p_stim_delay = $time - stim_op_start;
    if (p_stim_en_count == 1)
        p_stim_period = $time - p_stim_rise_t;   // 1 発目→2 発目の間隔 = PERIOD
    p_stim_rise_t   = $time;
    p_stim_en_count = p_stim_en_count + 1;
end

// 1 発目のパルス幅 = WIDTH
always @(negedge P_STIM_EN)
    if (p_stim_en_count == 1)
        p_stim_width = $time - p_stim_rise_t;

// !! 注意: この参照モデル (golden_encode / ビット詰め替え関数) は
//    CONV_ENCODER_TB.v / COM_CON_OUT_tb.v / TOP_202512TO_tb.v の 3 ファイルに
//    同じものがコピーされている。RTL 実装のバグが期待値へコピーされるのを防ぐため、
//    意図的に共有ヘッダ化していない。
//    生成多項式やビット順の仕様を変えるときは 3 ファイルすべてを直すこと。
// 参照モデル: 畳み込み符号化 (K=3, rate 1/2, G0=7(111), G1=5(101), MSB first)
function [63:0] golden_encode(input [31:0] d);
    integer k;
    reg s0, s1, b;
begin
    s0 = 1'b0;
    s1 = 1'b0;
    golden_encode = 64'b0;
    for (k = 0; k < 32; k = k + 1) begin
        b = d[31 - k];
        golden_encode[k*2]     = b ^ s0 ^ s1;   // c0
        golden_encode[k*2 + 1] = b ^ s1;        // c1
        s1 = s0;
        s0 = b;
    end
end
endfunction

// COM_CON_TOP.v の encoder_input と同じ並べ替え (各フィールドのビット順が反転する)
function [31:0] pack_frame(input [7:0] a, input [1:0] t, input [19:0] d);
    integer k;
begin
    for (k = 0; k < 8;  k = k + 1) pack_frame[31 - k] = a[k];
    for (k = 0; k < 2;  k = k + 1) pack_frame[23 - k] = t[k];
    for (k = 0; k < 20; k = k + 1) pack_frame[21 - k] = d[k];
    pack_frame[1] = 1'b0;
    pack_frame[0] = 1'b0;
end
endfunction

initial begin
    $display("========================================");
    $display("TOP_202512TO Testbench");
    $display("========================================");

    // Initialize signals
    ORDER = 1'b0;
    POR = 1'b0;
    DECODER_RST = 1'b1;
    unique_low = 2'b00;
    unique_debug = 1'b1;
    conv_encoder_state = 1'b1;
    ENCODE_ENABLE_ext = 1'b1;

    // ADC に変換させる 10bit コード (COMPARATOR 経由で注入される)
    adc_code_ele = 10'b10_0110_1011;
    adc_code_opt = 10'b01_1100_0101;

    for (ci = 0; ci < 128; ci = ci + 1) out_at[ci] = 1'bx;

    // Release POR
    #300;
    POR = 1'b1;
    #200;

    // Setup command for device
    @(posedge CLK) #delay ORDER = 1'b0; DECODER_RST = 1'b0;
    #(5*clock);
    @(posedge CLK) #delay ORDER = 1'b0; DECODER_RST = 1'b1;

    // 短コマンド (起動トリガ) の内容
    trig_cmd      = 20'b0;
    trig_cmd[7:0] = 8'b1111_1111;   // General Address
    trig_cmd[10]  = 1'b1;            // ← 起動ビット

    // ===================== 1 周目 =====================
    $display("\n========================================");
    $display(" 1 周目 (符号化 ON = 外部パッド / ADC 実測値)");
    $display("========================================");
    $display("\nSending command to device...");

    // 外部パッドで符号化 ON。conv_encoder_state=0 なので
    // デバッグ固定値ではなく ADC の実測値がシリアル出力に載る
    conv_encoder_state = 1'b0;
    ENCODE_ENABLE_ext  = 1'b1;
    build_command(8'h2c, 8'b1010_0000, 16'h000A, 16'h0005, 16'h0002, 16'h0001, 1'b1, 1'b0);
    reset_counters;
    send_full_command;

    $display("\n[1周目] フル設定コマンドの受信結果");
    expect_full_command;

    send_trigger_command;

    $display("\n[1周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for measurement cycles...\n");
    // Wait for measurements to complete
    // S_Bias signals are generated internally by MEASURE modules
    #(MEAS_WAIT);

    $display("[1周目] 動作結果");
    expect_measurement;

    $display("\n[1周目] シリアル出力フレームの検証");
    capture_frame;
    set_frame_expect;
    expect_frame;

    // ============ 2 周目 (1 周目と同じコマンドを再送) ============
    $display("\n========================================");
    $display(" 2 周目");
    $display("========================================");
    $display("\nSending command to device...");

    conv_encoder_state = 1'b0;
    ENCODE_ENABLE_ext  = 1'b1;
    build_command(8'h2c, 8'b1010_0000, 16'h000A, 16'h0005, 16'h0002, 16'h0001, 1'b1, 1'b0);
    reset_counters;
    send_full_command;

    // 回帰テスト: 修正前は COMMAND[10] の前回値により com=10 で打ち切られていた
    $display("\n[2周目] フル設定コマンドの受信結果");
    expect_full_command;

    send_trigger_command;

    $display("\n[2周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for measurement cycles...\n");
    #(MEAS_WAIT);

    $display("[2周目] 動作結果");
    expect_measurement;

    $display("\n[2周目] シリアル出力フレームの検証");
    capture_frame;
    set_frame_expect;
    expect_frame;

    // ====== 3 周目 (設定値を変えて再送し、変更が反映されるか) ======
    $display("\n========================================");
    $display(" 3 周目 (設定値を変更して再送 / 符号化 OFF)");
    $display("========================================");
    $display("\nSending command to device...");

    // 外部パッドを 0 に落とし、command[343]=0 と合わせて符号化 OFF にする。
    // ENCODE_ENABLE_ext を 1 に固定していた頃は command[343] の効果が
    // 一度も観測できなかったため、ここで非符号化パスを通す
    conv_encoder_state = 1'b0;
    ENCODE_ENABLE_ext  = 1'b0;
    // PERIOD/WIDTH を 1・2 周目と別の値にする。
    // 設定の上書きに失敗すると expect_full_command が古い値を検出して FAIL する
    build_command(8'h2c, 8'b1010_0000, 16'h0014, 16'h0008, 16'h0002, 16'h0001, 1'b1, 1'b0);
    reset_counters;
    send_full_command;

    $display("\n[3周目] フル設定コマンドの受信結果");
    expect_full_command;

    send_trigger_command;

    $display("\n[3周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for measurement cycles...\n");
    #(MEAS_WAIT);

    $display("[3周目] 動作結果");
    expect_measurement;

    $display("\n[3周目] シリアル出力フレームの検証 (符号化 OFF パス)");
    capture_frame;
    set_frame_expect;
    expect_frame;

    // ============ 4 周目 (刺激 ON / 計測 OFF) ============
    $display("\n========================================");
    $display(" 4 周目 (刺激 ON / 計測 OFF)");
    $display("========================================");
    $display("\nSending command to device...");

    // bit17=0:光測定OFF bit16=1:光刺激ON bit15=0:電気測定OFF bit14=1:電気刺激ON
    build_command(8'h2c, 8'b0101_0000, 16'h000A, 16'h0005, 16'h0002, 16'h0001, 1'b1, 1'b0);
    reset_counters;
    send_full_command;

    $display("\n[4周目] フル設定コマンドの受信結果");
    expect_full_command;

    send_trigger_command;

    $display("\n[4周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for stimulation...\n");
    #(STIM_WAIT);

    $display("[4周目] 動作結果");
    expect_stimulation;

    // ====== 5 周目 (刺激をもう一度起動し、DELAY がずれないか) ======
    // STIM の msec_count が前回から持ち越されると DELAY の起点がずれる
    $display("\n========================================");
    $display(" 5 周目 (刺激 ON / 計測 OFF, 2 回目)");
    $display("========================================");
    $display("\nSending command to device...");

    build_command(8'h2c, 8'b0101_0000, 16'h000A, 16'h0005, 16'h0002, 16'h0001, 1'b1, 1'b0);
    reset_counters;
    send_full_command;

    $display("\n[5周目] フル設定コマンドの受信結果");
    expect_full_command;

    send_trigger_command;

    $display("\n[5周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for stimulation...\n");
    #(STIM_WAIT);

    $display("[5周目] 動作結果");
    expect_stimulation;

    // ====== 6 周目 (command[343] で符号化 ON / デバッグ固定データ) ======
    // ENCODE_ENABLE_ext は 0 のまま。符号化が有効になるなら command[343] の効果
    $display("\n========================================");
    $display(" 6 周目 (符号化 ON = command[343] / デバッグ固定データ)");
    $display("========================================");
    $display("\nSending command to device...");

    conv_encoder_state = 1'b1;      // COM_CON_OUT の DEBUG_TEST_DATA を載せる
    ENCODE_ENABLE_ext  = 1'b0;      // 外部パッドは OFF
    build_command(8'h2c, 8'b1010_0000, 16'h000A, 16'h0005, 16'h0002, 16'h0001, 1'b1, 1'b1);
    reset_counters;
    send_full_command;

    $display("\n[6周目] フル設定コマンドの受信結果");
    expect_full_command;
    `CHECK(dut.command[343] == 1'b1, "符号化ビット command[343] が 1 で受信された")

    send_trigger_command;

    $display("\n[6周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for measurement cycles...\n");
    #(MEAS_WAIT);

    $display("[6周目] 動作結果");
    expect_measurement;

    $display("\n[6周目] シリアル出力フレームの検証 (command[343] による符号化)");
    capture_frame;
    set_frame_expect;
    expect_frame;

    // ============ 7 周目 (他デバイス宛てコマンドの拒否) ============
    $display("\n========================================");
    $display(" 7 周目 (他デバイス宛てコマンドを無視するか)");
    $display("========================================");
    $display("\nSending command to another device (0x2d)...");

    cmd_before = dut.command;
    reset_counters;
    // 自機アドレス 0x2c でも general 0xff でもないアドレスへ送る
    build_command(8'h2d, 8'b1010_0000, 16'hBEEF, 16'hCAFE, 16'h0009, 16'h0007, 1'b1, 1'b1);
    send_full_command;

    $display("\n[7周目] 受信結果");
    $display("  (書き込み到達点 com=%0d / 自機アドレス=%h)", com_peak, unique_addr);
    expect_address_reject;

    // ====== 8 周目 (刺激パルスの幅・周期・回数の定量検証) ======
    // N極を無効にして P極だけを単独で観測する。短いパラメータで 3 発撃たせる
    $display("\n========================================");
    $display(" 8 周目 (刺激パルスの定量検証)");
    $display("========================================");
    $display("\nSending command to device...");

    // bit16=1:光刺激ON bit14=1:電気刺激ON / 測定は OFF
    // PERIOD=3ms WIDTH=1ms LOOP=3 DELAY=1ms, N極 OPERATE=0
    build_command(8'h2c, 8'b0101_0000, 16'h0003, 16'h0001, 16'h0003, 16'h0001, 1'b0, 1'b0);
    reset_counters;
    send_full_command;

    $display("\n[8周目] フル設定コマンドの受信結果");
    expect_full_command;

    send_trigger_command;

    $display("\n[8周目] 短コマンド (起動トリガ) の受信結果");
    expect_trigger_command;

    show_command_state;

    $display("\nWaiting for stimulation...\n");
    #(STIM_TIMING_WAIT);

    $display("[8周目] 動作結果");
    expect_stim_timing;

    // ===================== 結果サマリ =====================
    $display("\n========================================");
    $display(" テスト結果");
    $display("========================================");
    $display("  チェック項目 : %0d", checks);
    $display("  成功         : %0d", checks - errors);
    $display("  失敗         : %0d", errors);
    $display("========================================");

    #100000;

    if (errors != 0)
        $fatal(1, "TEST FAILED (%0d 件失敗)", errors);

    $display("TEST PASSED");
    $finish;
end

// ---------------------------------------------------------------
// コマンド組み立て
// ---------------------------------------------------------------

// フル設定コマンドを組み立てる
//   addr         : 宛先アドレス
//   enable_bits  : command[17:10] に入るイネーブル部
//                  bit17=光測定 bit16=光刺激 bit15=電気測定 bit14=電気刺激 bit10=起動
//   ele_p_period : 電気刺激P の PERIOD
//   ele_p_width  : 電気刺激P の WIDTH
// これ以外のパラメータは固定値。expect_full_command が参照する期待値も同時に保存する
task build_command(input [7:0] addr, input [7:0] enable_bits,
                   input [15:0] ele_p_period, input [15:0] ele_p_width,
                   input [15:0] ele_p_loop,   input [15:0] ele_p_delay,
                   input ele_n_operate,       input encode_bit);
begin
    exp_addr         = addr;
    exp_enable       = enable_bits;
    exp_ele_p_period = ele_p_period;
    exp_ele_p_width  = ele_p_width;
    exp_ele_p_loop   = ele_p_loop;
    exp_ele_p_delay  = ele_p_delay;
    exp_encode_bit   = encode_bit;

    command = 400'b0;

    command[7:0]   = addr;
    command[17:10] = enable_bits;

    // Electric stimulation P settings
    {command[37:30], command[27:20]} = ele_p_period;
    {command[57:50], command[47:40]} = ele_p_width;
    {command[77:70], command[67:60]} = ele_p_loop;
    {command[97:90], command[87:80]} = ele_p_delay;
    command[107:100] = 8'b00_1_11111;                 // enable & intensity

    // Electric stimulation N settings
    {command[127:120], command[117:110]} = 16'h000A;  // period
    {command[147:140], command[137:130]} = 16'h0005;  // width
    {command[167:160], command[157:150]} = 16'h0002;  // loop
    {command[187:180], command[177:170]} = 16'h0006;  // delay
    // bit195 = N極の個別 OPERATE。0 にすると P極だけを単独で観測できる
    command[197:190] = {2'b00, ele_n_operate, 5'b11111};

    // Electric measurement settings
    {command[217:210], command[207:200]} = 16'h0000;  // delay
    command[227:220] = 8'b0000_1111;

    // Optical stimulation settings
    {command[247:240], command[237:230]} = 16'h000A;  // period
    {command[267:260], command[257:250]} = 16'h0002;  // width
    {command[287:280], command[277:270]} = 16'h0002;  // loop
    {command[307:300], command[297:290]} = 16'h0000;  // delay
    command[317:310] = 8'b0001_1111;                  // intensity

    // Optical measurement settings
    {command[337:330], command[327:320]} = 16'h0000;  // delay
    // bit343 = ENCODE_ENABLE (畳み込み符号化 ON/OFF)
    command[347:340] = {4'b0000, encode_bit, 3'b111};
end
endtask

// ---------------------------------------------------------------
// 検証タスク
// ---------------------------------------------------------------

// フル設定コマンドが最後まで正しく受信されたか
task expect_full_command;
begin
    $display("  (期待値 addr=%h enable=%b PERIOD=%h WIDTH=%h)",
             exp_addr, exp_enable, exp_ele_p_period, exp_ele_p_width);
    `CHECK(com_peak >= 350,                  "350bit 全部が書き込まれた (com >= 350)")
    `CHECK(dut.COMMAND.state == 1'b0,        "送信後に standby へ復帰した")
    `CHECK(dut.command[7:0] == exp_addr,     "宛先アドレスで受理された")
    `CHECK(dut.command[10] == 1'b0,          "起動ビット bit10 は 0")
    `CHECK(dut.command[17:10] == exp_enable, "イネーブル部 bit[17:10] が一致")
    `CHECK({dut.command[37:30], dut.command[27:20]} == exp_ele_p_period, "電気刺激P PERIOD が一致")
    `CHECK({dut.command[57:50], dut.command[47:40]} == exp_ele_p_width,  "電気刺激P WIDTH が一致")
end
endtask

// 短コマンドで起動がかかり、かつ設定が保持されているか
task expect_trigger_command;
begin
    `CHECK(dut.command[7:0] == 8'hff,             "General Address 0xFF で受理された")
    `CHECK(dut.command[10] == 1'b1,               "起動ビット bit10 が立った")
    `CHECK(dut.command[17:11] == exp_enable[7:1], "イネーブル設定 bit[17:11] が保持されている")
end
endtask

// 測定モード: 測定が周期通りに走り、出力が出たか
task expect_measurement;
begin
    `CHECK(sbias_ele_count == EXPECT_MEAS, "電気測定が期待回数走った")
    `CHECK(sbias_opt_count == EXPECT_MEAS, "光測定が期待回数走った")
    `CHECK(sbias_ele_bad_gap == 0,      "電気測定の間隔が 1ms で一定")
    `CHECK(sbias_opt_bad_gap == 0,      "光測定の間隔が 1ms で一定")
    `CHECK(serial_toggles > 0,          "SERIAL_OUT にデータが出た")
end
endtask

// 刺激モード: 刺激が出力され、測定は止まっているか
task expect_stimulation;
begin
    $display("  (実測 P_STIM_EN=%0d回 N_STIM_EN=%0d回 OPT_STIM=%0d変化)",
             p_stim_en_count, n_stim_en_count, opt_stim_toggles);
    $display("  (実測 電気刺激P DELAY = %0d ns / 設定 %0d ns)", p_stim_delay, ELE_P_DELAY);
    `CHECK(p_stim_en_count > 0,   "電気刺激P が発火した")
    `CHECK(n_stim_en_count > 0,   "電気刺激N が発火した")
    `CHECK(opt_stim_toggles > 0,  "光刺激が出力された")
    `CHECK(sbias_ele_count == 0,  "電気測定は動いていない")
    `CHECK(sbias_opt_count == 0,  "光測定は動いていない")
    // 起動から最初の刺激までが設定 DELAY どおりか (state 遷移の内部遅延ぶん数クロック分の余裕を見る)
    `CHECK(p_stim_delay >= ELE_P_DELAY && p_stim_delay <= ELE_P_DELAY + 5*clock,
           "電気刺激P の DELAY が設定値どおり")
end
endtask

// 刺激の定量検証: パルス幅 = WIDTH, 周期 = PERIOD, 発火回数 = LOOP
// (N極を無効にして P極だけを単独で観測している前提)
//
// 幅・周期とも実測は設定値ちょうど -1クロック になる。
// STIM.v は state が on へ遷移してから STIM を立てるため、1 発目の立ち上がりだけが
// msec カウンタの刻みより 1 クロック遅れる。2 発目以降は純粋にカウンタ駆動なので、
// 1 発目起点で測る幅と周期はどちらも 1 クロックぶん短く出る。
// 仕様どおりかを見たいので、許容幅は 1 クロックに絞る。
task expect_stim_timing;
begin
    $display("  (パルス幅   実測 %0d ns / 設定 WIDTH=%0d ms)",  p_stim_width,  exp_ele_p_width);
    $display("  (パルス周期 実測 %0d ns / 設定 PERIOD=%0d ms)", p_stim_period, exp_ele_p_period);
    $display("  (発火回数   実測 %0d 回 / 設定 LOOP=%0d)",      p_stim_en_count, exp_ele_p_loop);
    `CHECK(p_stim_width  >= exp_ele_p_width  * MSEC - clock &&
           p_stim_width  <= exp_ele_p_width  * MSEC,
           "電気刺激P のパルス幅が WIDTH どおり (±1clk)")
    `CHECK(p_stim_period >= exp_ele_p_period * MSEC - clock &&
           p_stim_period <= exp_ele_p_period * MSEC,
           "電気刺激P の周期が PERIOD どおり (±1clk)")
    `CHECK(p_stim_en_count == exp_ele_p_loop,         "電気刺激P の発火回数が LOOP どおり")
    `CHECK(n_stim_en_count == 0,                      "N極 OPERATE=0 のとき N極は発火しない")
end
endtask

// ---------------------------------------------------------------
// シリアル出力フレームの検証
// ---------------------------------------------------------------

// 次の 1 フレームを取り込む
task capture_frame;
    integer n;
begin
    // いま送信中なら終わるまで待つ
    n = 0;
    while ((ser_enable !== 1'b0) && (n < 100000)) begin @(posedge CLK); n = n + 1; end

    // 送信していない間に観測をクリアする (キャプチャ用 always とは競合しない)
    for (ci = 0; ci < 128; ci = ci + 1) out_at[ci] = 1'bx;

    // 次のフレーム開始を待つ
    n = 0;
    while ((ser_enable !== 1'b1) && (n < 200000)) begin @(posedge CLK); n = n + 1; end
    frame_seen = (ser_enable === 1'b1) ? 1 : 0;

    // フレーム終了を待つ
    n = 0;
    while ((ser_enable !== 1'b0) && (n < 5000)) begin @(posedge CLK); n = n + 1; end
end
endtask

// このフレームの期待値を確定させる
task set_frame_expect;
begin
    exp_encode_on     = exp_encode_bit | ENCODE_ENABLE_ext;
    exp_frame_data    = conv_encoder_state ? DEBUG_TEST_DATA : {adc_code_opt, adc_code_ele};
    exp_frame_type    = {exp_enable[7], exp_enable[5]};   // {command[17], command[15]}
    exp_frame_enc_in  = pack_frame(unique_addr, exp_frame_type, exp_frame_data);
    exp_frame_enc_out = golden_encode(exp_frame_enc_in);
end
endtask

// 取り込んだフレームの中身を検証する
task expect_frame;
begin
    // 日本語文字列を三項演算子で選ぶと幅が揃わず化けるので if で分ける
    if (conv_encoder_state)
        $display("  (符号化 %0s / データ源 デバッグ固定値)", exp_encode_on ? "ON" : "OFF");
    else
        $display("  (符号化 %0s / データ源 ADC 実測値)",     exp_encode_on ? "ON" : "OFF");

    `CHECK(frame_seen == 1, "測定後にシリアルフレームが送出された")

    // ADC が COMPARATOR パターンどおりの符号を出したか
    `CHECK(dut.DATA_ELE === adc_code_ele, "電気測定 ADC が注入コードどおりに変換した")
    `CHECK(dut.DATA_OPT === adc_code_opt, "光測定 ADC が注入コードどおりに変換した")

    // プリアンブル
    frame_preamble_bad = 0;
    for (ci = F_PRE_LO + 1; ci <= F_PRE_HI; ci = ci + 1)
        if (out_at[ci] === out_at[ci-1]) frame_preamble_bad = frame_preamble_bad + 1;
    `CHECK(frame_preamble_bad == 0, "プリアンブル 32bit が 1bit ごとに反転している")

    if (exp_encode_on) begin
        for (ci = 0; ci < 64; ci = ci + 1) got_frame_enc[ci] = out_at[F_ENC_LO + ci];
        $display("  (符号化入力   %08h)", exp_frame_enc_in);
        $display("  (符号化データ 期待 %016h / 実測 %016h)", exp_frame_enc_out, got_frame_enc);
        `CHECK(got_frame_enc === exp_frame_enc_out,
               "符号化データ 64bit が参照モデルと一致")
        frame_stop_bad = 0;
        for (ci = F_SON_LO; ci <= F_SON_HI; ci = ci + 1)
            if (out_at[ci] !== 1'b1) frame_stop_bad = frame_stop_bad + 1;
        `CHECK(frame_stop_bad == 0, "ストップビット 3bit がすべて 1")
    end
    else begin
        for (ci = 0; ci < 8;  ci = ci + 1) got_frame_addr[ci] = out_at[F_ADDR_LO + ci];
        for (ci = 0; ci < 2;  ci = ci + 1) got_frame_type[ci] = out_at[F_TYPE_LO + ci];
        for (ci = 0; ci < 20; ci = ci + 1) got_frame_data[ci] = out_at[F_DATA_LO + ci];
        $display("  (ADDRESS 期待 %b / 実測 %b)",   unique_addr,    got_frame_addr);
        $display("  (TYPE    期待 %b / 実測 %b)",   exp_frame_type, got_frame_type);
        $display("  (DATA    期待 %05h / 実測 %05h)", exp_frame_data, got_frame_data);
        `CHECK(got_frame_addr === unique_addr,     "ADDRESS 8bit が自機アドレスで出力された")
        `CHECK(got_frame_type === exp_frame_type,  "TYPE 2bit がイネーブル設定どおり")
        `CHECK(got_frame_data === exp_frame_data,  "DATA 20bit が ADC 実測値どおり")
        frame_stop_bad = 0;
        for (ci = F_SOFF_LO; ci <= F_SOFF_HI; ci = ci + 1)
            if (out_at[ci] !== 1'b1) frame_stop_bad = frame_stop_bad + 1;
        `CHECK(frame_stop_bad == 0, "ストップビット 3bit がすべて 1")
    end
end
endtask

// 他デバイス宛てコマンドを無視するか
// COMMAND.v はアドレス 8bit を受け切った時点 (com >= 8) で不一致を判定して中断するため、
// 先頭バイトは書き込まれるがパラメータ領域 (bit20 以降) は変化しない
task expect_address_reject;
begin
    `CHECK(dut.COMMAND.state == 1'b0,
           "他デバイス宛てコマンドの後も standby へ戻っている")
    `CHECK(dut.command[399:20] === cmd_before[399:20],
           "他デバイス宛てコマンドでパラメータ領域が書き換わらない")
    `CHECK(com_peak < 350,
           "アドレス不一致で書き込みが途中で打ち切られた")
end
endtask

// ---------------------------------------------------------------
// コマンド送信タスク
// ---------------------------------------------------------------

// フル設定コマンド (350bit) を送る
task send_full_command;
begin
    // Send command via ORDER signal
    @(posedge CLK) #delay ORDER = 1'b0; DECODER_RST = 1'b0;
    @(posedge CLK) #delay ORDER = 1'b1; DECODER_RST = 1'b1;
    #(10*clock);

    for(J = 0; J < 350; J = J+10) begin
        @(posedge CLK) #delay; ORDER = 1'b0;

        @(posedge CLK) #delay; ORDER = command[J];
        @(posedge CLK) #delay; ORDER = command[J+1];
        @(posedge CLK) #delay; ORDER = command[J+2];
        @(posedge CLK) #delay; ORDER = command[J+3];
        @(posedge CLK) #delay; ORDER = command[J+4];
        @(posedge CLK) #delay; ORDER = command[J+5];
        @(posedge CLK) #delay; ORDER = command[J+6];
        @(posedge CLK) #delay; ORDER = command[J+7];

        @(posedge CLK) #delay; ORDER = 1'b1;
    end

    @(posedge CLK) #delay ORDER = 1'b0;
    #(10*clock);
    @(posedge CLK) #delay ORDER = 1'b1;
    @(posedge CLK) #delay ORDER = 1'b0;
    #(10*clock);
end
endtask

// 短コマンド (アドレス + 起動ビット bit10) を送る
task send_trigger_command;
begin
    @(posedge CLK) #delay ORDER = 1'b1;
    #(10*clock);

    // 2バイト分送信 (アドレス + bit10=1 byte)
    for(J = 0; J < 20; J = J+10) begin
        @(posedge CLK) #delay; ORDER = 1'b0;
        @(posedge CLK) #delay; ORDER = trig_cmd[J];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+1];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+2];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+3];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+4];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+5];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+6];
        @(posedge CLK) #delay; ORDER = trig_cmd[J+7];
        @(posedge CLK) #delay; ORDER = 1'b1;
    end

    @(posedge CLK) #delay ORDER = 1'b0;
    #(10*clock);
    @(posedge CLK) #delay ORDER = 1'b1;
    @(posedge CLK) #delay ORDER = 1'b0;
    #(10*clock);
end
endtask

// 周回ごとの観測カウンタをリセットする
task reset_counters;
begin
    com_peak          = 0;
    sbias_ele_count   = 0;
    sbias_opt_count   = 0;
    serial_toggles    = 0;
    p_stim_en_count   = 0;
    n_stim_en_count   = 0;
    opt_stim_toggles  = 0;
    sbias_ele_prev    = 0;
    sbias_opt_prev    = 0;
    sbias_ele_bad_gap = 0;
    sbias_opt_bad_gap = 0;
    stim_op_start     = 0;
    p_stim_delay      = 0;
    p_stim_rise_t     = 0;
    p_stim_width      = 0;
    p_stim_period     = 0;
    frame_seen        = 0;
end
endtask

// DUT 内の COMMAND レジスタが何を受け取ったかを表示する
task show_command_state;
begin
    $display("  COMMAND state : %b (0:standby / 1:write)", dut.COMMAND.state);
    $display("  address [7:0] : %h", dut.command[7:0]);
    $display("  bit10/15/17   : %b / %b / %b",
             dut.command[10], dut.command[15], dut.command[17]);
end
endtask

// 全体ウォッチドッグ
// 待ちはすべて固定時間か上限付き while ループなので現状ハングする経路は無いが、
// 将来の RTL 変更で止まったときに CI が無限に待たないよう上限を設ける。
// 通常は約 38ms で $finish に到達する
initial begin
    #60000000;
    $fatal(1, "TESTBENCH TIMEOUT (シミュレーションが終わらなかった)");
end

// VCD dump for waveform viewing
initial begin
    $dumpfile("TOP_202512TO_tb.vcd");
    $dumpvars(0, TOP_202512TO_tb);
end

endmodule
