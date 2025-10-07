//COM_CON_TOP for multi device + new 10bit ADC

module COM_CON_TOP (
    input CLK, POR, ADC_STATE,
    input [1:0] OPERATE, TYPE,
    input [7:0] ADDRESS,
    input [19:0] DATA,
    input [9:0] OPT_DELAY, ELE_DELAY,
    output OUT, ENABLE
);

// ?????????
// ???????reg?????
wire C_OUT1, S_OUT, S_ADDRESS, CLK50;
wire [2:0] state_comcon;

//??????(delay ??)
COM_ENABLE COM_ENABLE(
.CLK(CLK),.POR(POR),
.ADC_STATE(ADC_STATE),
.DELAY(ADDRESS[3:0]),
.OPERATE(OPERATE),
.OPT_DELAY(OPT_DELAY),
.ELE_DELAY(ELE_DELAY),
.CLK50(CLK50),
.ENABLE(ENABLE)
);


// ??????????
COUNTER_COMCON COUNTER_COMCON(
.CLK(CLK),
.CLK50(CLK50),
.POR(POR),
.ADC_STATE(ADC_STATE),
.ENABLE(ENABLE),
.state(state_comcon),
.C_OUT1(C_OUT1)
);

// ????????
SHIFT_REG SHIFT_REG(
.CLK(CLK),
.CLK50(CLK50),
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
.CLK50(CLK50),
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
