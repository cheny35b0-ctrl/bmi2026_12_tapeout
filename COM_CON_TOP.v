//COM_CON_TOP for multi device + new 10bit ADC

module COM_CON_TOP (
    input CLK, POR, S_Bias_OPT, S_Bias_ELE,
    input [1:0] OPERATE, TYPE,
    input [7:0] ADDRESS,
    input [19:0] DATA,
    output OUT, ENABLE
);

// ADC_STATE synchronization
reg ADC_STATE;

always @(posedge CLK or negedge POR) begin
    if (!POR)
        ADC_STATE <= 1'b0;
    else
        ADC_STATE <= S_Bias_OPT || S_Bias_ELE;
end

wire C_OUT1, S_OUT, S_ADDRESS, CLK5;
wire [2:0] state_comcon;

COM_ENABLE COM_ENABLE(
.CLK(CLK),.POR(POR),
.ADC_STATE(ADC_STATE),
.DELAY(ADDRESS[3:0]),
.OPERATE(OPERATE),
.CLK5(CLK5),
.ENABLE(ENABLE)
);


COUNTER_COMCON COUNTER_COMCON(
.CLK(CLK),
.CLK5(CLK5),
.POR(POR),
.ADC_STATE(ADC_STATE),
.state(state_comcon),
.C_OUT1(C_OUT1)
);

SHIFT_REG SHIFT_REG(
.CLK(CLK),
.CLK5(CLK5),
.POR(POR),
.ADC_STATE(ADC_STATE),
.ENABLE(ENABLE),
.state(state_comcon),
.DATA(DATA[19:0]),
.S_OUT(S_OUT)
);

// state
SELECT SELECT(
.CLK(CLK),
.CLK5(CLK5),
.POR(POR),
.ADC_STATE(ADC_STATE),
.ENABLE(ENABLE),
.state(state_comcon),
.TYPE(TYPE),
.C_OUT1(C_OUT1),
.S_OUT(S_OUT),
.OUT(OUT),
.ADDRESS(ADDRESS[7:0])
);

endmodule
