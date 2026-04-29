`timescale 1ns/1ps

module TOP_202512TO_tb;

// Clock and reset
reg CLK;
reg POR;
reg ORDER;

// Address inputs
reg [1:0] unique_low;
reg unique_debug;

// Manchester decoder
reg MAN;
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
reg [3:0] DEBUG_DATA_LOWER;
reg S_Bias_ELE_IN;
reg S_Bias_OPT_IN;
reg ENCODE_ENABLE_ext;

// Communication control
wire SERIAL_OUT;

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
    .DEBUG_DATA_LOWER(DEBUG_DATA_LOWER),
    .S_Bias_ELE_IN(S_Bias_ELE_IN),
    .S_Bias_OPT_IN(S_Bias_OPT_IN),
    .ENCODE_ENABLE_ext(ENCODE_ENABLE_ext),
    .SERIAL_OUT(SERIAL_OUT)
);

// Clock generation (100MHz)
initial begin
    CLK = 0;
    forever #5 CLK = ~CLK;
end

// Test sequence
initial begin
    // Initialize
    POR = 0;
    ORDER = 0;
    unique_low = 2'b00;
    unique_debug = 0;
    MAN = 0;
    DECODER_RST = 0;
    COMPARATOR_ELE = 0;
    COMPARATOR_OPT = 0;
    conv_encoder_state = 0;
    DEBUG_DATA_LOWER = 4'b0000;
    S_Bias_ELE_IN = 0;
    S_Bias_OPT_IN = 0;
    ENCODE_ENABLE_ext = 0;

    // Release reset
    #20;
    POR = 1;
    #20;

    $display("========================================");
    $display("Address Debug Test Start");
    $display("========================================");

    // Test 1: unique_debug = 0, unique_low = 2'b00
    // Expected: unique = 8'b00000000
    unique_debug = 0;
    unique_low = 2'b00;
    #20;
    $display("Test 1: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00000000");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00000000)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 2: unique_debug = 0, unique_low = 2'b01
    // Expected: unique = 8'b00000001
    unique_debug = 0;
    unique_low = 2'b01;
    #20;
    $display("\nTest 2: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00000001");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00000001)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 3: unique_debug = 0, unique_low = 2'b10
    // Expected: unique = 8'b00000010
    unique_debug = 0;
    unique_low = 2'b10;
    #20;
    $display("\nTest 3: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00000010");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00000010)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 4: unique_debug = 0, unique_low = 2'b11
    // Expected: unique = 8'b00000011
    unique_debug = 0;
    unique_low = 2'b11;
    #20;
    $display("\nTest 4: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00000011");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00000011)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 5: unique_debug = 1, unique_low = 2'b00
    // Expected: unique = 8'b00111100
    unique_debug = 1;
    unique_low = 2'b00;
    #20;
    $display("\nTest 5: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00111100");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00111100)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 6: unique_debug = 1, unique_low = 2'b01
    // Expected: unique = 8'b00111101
    unique_debug = 1;
    unique_low = 2'b01;
    #20;
    $display("\nTest 6: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00111101");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00111101)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 7: unique_debug = 1, unique_low = 2'b10
    // Expected: unique = 8'b00111110
    unique_debug = 1;
    unique_low = 2'b10;
    #20;
    $display("\nTest 7: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00111110");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00111110)
        $display("  PASS");
    else
        $display("  FAIL");

    // Test 8: unique_debug = 1, unique_low = 2'b11
    // Expected: unique = 8'b00111111
    unique_debug = 1;
    unique_low = 2'b11;
    #20;
    $display("\nTest 8: unique_debug=%b, unique_low=%b", unique_debug, unique_low);
    $display("  Expected unique: 8'b00111111");
    $display("  Actual unique:   8'b%b", dut.unique);
    if (dut.unique === 8'b00111111)
        $display("  PASS");
    else
        $display("  FAIL");

    $display("\n========================================");
    $display("Address Debug Test Complete");
    $display("========================================");

    #100;
    $finish;
end

// VCD dump for waveform viewing
initial begin
    $dumpfile("TOP_202512TO_tb.vcd");
    $dumpvars(0, TOP_202512TO_tb);
end

endmodule
