`timescale 1ns/1ns

module TOP_202512TO_tb;

parameter delay = 0;
parameter clock = 100;

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

// build_command が組み立てた値。expect_full_command が期待値として参照する
reg [7:0]  exp_addr;
reg [7:0]  exp_enable;
reg [15:0] exp_ele_p_period;
reg [15:0] exp_ele_p_width;

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
    p_stim_en_count = p_stim_en_count + 1;
end

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
    COMPARATOR_ELE = 1'b0;
    COMPARATOR_OPT = 1'b0;
    conv_encoder_state = 1'b1;
    ENCODE_ENABLE_ext = 1'b1;

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
    $display(" 1 周目");
    $display("========================================");
    $display("\nSending command to device...");

    build_command(8'h2c, 8'b1010_0000, 16'h000A, 16'h0005);
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

    // ============ 2 周目 (1 周目と同じコマンドを再送) ============
    $display("\n========================================");
    $display(" 2 周目");
    $display("========================================");
    $display("\nSending command to device...");

    build_command(8'h2c, 8'b1010_0000, 16'h000A, 16'h0005);
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

    // ====== 3 周目 (設定値を変えて再送し、変更が反映されるか) ======
    $display("\n========================================");
    $display(" 3 周目 (設定値を変更して再送)");
    $display("========================================");
    $display("\nSending command to device...");

    // PERIOD/WIDTH を 1・2 周目と別の値にする。
    // 設定の上書きに失敗すると expect_full_command が古い値を検出して FAIL する
    build_command(8'h2c, 8'b1010_0000, 16'h0014, 16'h0008);
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

    // ============ 4 周目 (刺激 ON / 計測 OFF) ============
    $display("\n========================================");
    $display(" 4 周目 (刺激 ON / 計測 OFF)");
    $display("========================================");
    $display("\nSending command to device...");

    // bit17=0:光測定OFF bit16=1:光刺激ON bit15=0:電気測定OFF bit14=1:電気刺激ON
    build_command(8'h2c, 8'b0101_0000, 16'h000A, 16'h0005);
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

    build_command(8'h2c, 8'b0101_0000, 16'h000A, 16'h0005);
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
                   input [15:0] ele_p_period, input [15:0] ele_p_width);
begin
    exp_addr         = addr;
    exp_enable       = enable_bits;
    exp_ele_p_period = ele_p_period;
    exp_ele_p_width  = ele_p_width;

    command = 400'b0;

    command[7:0]   = addr;
    command[17:10] = enable_bits;

    // Electric stimulation P settings
    {command[37:30], command[27:20]} = ele_p_period;
    {command[57:50], command[47:40]} = ele_p_width;
    {command[77:70], command[67:60]} = 16'h0002;      // loop
    {command[97:90], command[87:80]} = 16'h0001;      // delay
    command[107:100] = 8'b00_1_11111;                 // enable & intensity

    // Electric stimulation N settings
    {command[127:120], command[117:110]} = 16'h000A;  // period
    {command[147:140], command[137:130]} = 16'h0005;  // width
    {command[167:160], command[157:150]} = 16'h0002;  // loop
    {command[187:180], command[177:170]} = 16'h0006;  // delay
    command[197:190] = 8'b00_1_11111;                 // enable & intensity

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
    command[347:340] = 8'b0000_0111;
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

// VCD dump for waveform viewing
initial begin
    $dumpfile("TOP_202512TO_tb.vcd");
    $dumpvars(0, TOP_202512TO_tb);
end

endmodule
