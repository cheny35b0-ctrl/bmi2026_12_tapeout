`timescale 1ns/1ns

module TOP_202512TO_tb;

parameter delay = 0;
parameter clock = 100;

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

// CLOCK generation (100MHz)
always begin
    CLK = 1'b1;
    #50 CLK = 1'b0;
    #50;
end

// Manchester encoding
assign MAN = (CLK ^| ORDER);

integer J;

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

    command [7:0]     = 8'b0010_1100;  // address (unique_low = 01)
    command [17:10]   = 8'b1010_0000;  // enable (bit[10]=general, bit[15]=ELE, bit[17]=OPT)

    // Electric stimulation P settings
    {command [37:30],command[27:20]}    = 16'h000A;  // period
    {command [57:50],command[47:40]}    = 16'h0005;  // width
    {command [77:70],command[67:60]}    = 16'h0002;  // loop
    {command [97:90],command[87:80]}    = 16'h0001;  // delay
    command [107:100]   = 8'b00_1_11111;  // enable & intensity

    // Electric stimulation N settings
    {command [127:120],command[117:110]}    = 16'h000A;  // period
    {command [147:140],command[137:130]}    = 16'h0005;  // width
    {command [167:160],command[157:150]}    = 16'h0002;  // loop
    {command [187:180],command[177:170]}    = 16'h0006;  // delay
    command [197:190]   = 8'b00_1_11111;  // enable & intensity

    // Electric measurement settings
    {command [217:210],command[207:200]}    = 16'h0000;  // delay
    command [227:220]   = 8'b0000_1111;

    // Optical stimulation settings
    {command [247:240],command[237:230]}    = 16'h000A;  // period
    {command [267:260],command[257:250]}    = 16'h0002;  // width
    {command [287:280],command[277:270]}    = 16'h0002;  // loop
    {command [307:300],command[297:290]}    = 16'h0000;  // delay
    command [317:310]   = 8'b0001_1111;  // intensity

    // Optical measurement settings
    {command [337:330],command[327:320]}    = 16'h0000;  // delay
    command [347:340]   = 8'b0000_0111;

    // 短コマンド (起動トリガ) の内容
    trig_cmd      = 20'b0;
    trig_cmd[7:0] = 8'b1111_1111;   // General Address
    trig_cmd[10]  = 1'b1;            // ← 起動ビット

    // ===================== 1 周目 =====================
    $display("\n========================================");
    $display(" 1 周目");
    $display("========================================");
    $display("\nSending command to device...");

    send_full_command;
    send_trigger_command;

    $display("Command sent successfully");
    show_command_state;

    $display("\nWaiting for measurement cycles...\n");
    // Wait for measurements to complete
    // S_Bias signals are generated internally by MEASURE modules
    #2500000;

    // ============ 2 周目 (1 周目と同じコマンドを再送) ============
    $display("\n========================================");
    $display(" 2 周目");
    $display("========================================");
    $display("\nSending command to device...");

    send_full_command;
    send_trigger_command;

    $display("Command sent successfully");
    show_command_state;

    $display("\nWaiting for measurement cycles...\n");
    #2500000;

    $display("\n========================================");
    $display("Test Complete");
    $display("========================================");
    $display("Check waveform for SERIAL_OUT");

    #100000;
    $finish;
end

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
