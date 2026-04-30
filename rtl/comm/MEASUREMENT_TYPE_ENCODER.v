// MEASUREMENT_TYPE_ENCODER - Encodes OPERATE_OPT and OPERATE_ELE signals into 2-bit output

module MEASUREMENT_TYPE_ENCODER (
    input CLK, POR,
    input OPERATE_OPT,
    input OPERATE_ELE,
    output reg [1:0] OUT
);

always @(posedge CLK or negedge POR) begin
    if (!POR)
        OUT <= 2'b00;
    else
        case ({OPERATE_OPT, OPERATE_ELE})
            2'b10: OUT <= 2'b10;  // OPT only
            2'b01: OUT <= 2'b01;  // ELE only
            2'b11: OUT <= 2'b11;  // Both
            2'b00: OUT <= 2'b00;  // Neither
        endcase
end

endmodule
