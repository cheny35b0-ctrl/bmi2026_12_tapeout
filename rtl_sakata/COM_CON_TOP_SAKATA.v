//COM_CON_TOP for multi device + new 10bit ADC

module COM_CON_TOP_SAKATA (
    input CLK, POR, ADC_state,TYPE,OPERATE,
    input [7:0] ADDRESS,
    input [9:0] DATA,
    input [9:0] def_delay,
    output OUT,ENABLE
);

wire C_OUT1, S_OUT, S_ADDRESS, CLK25;
wire [2:0] state_comcon;

COM_ENABLE_SAKATA COM_ENABLE_SAKATA(
.CLK(CLK),.POR(POR),
.ADC_state(ADC_state),
.DELAY(ADDRESS[3:0]),
.OPERATE(OPERATE),
.def_delay(def_delay[9:0]),
.CLK25(CLK25),
.ENABLE(ENABLE)
);

COUNTER_COMCON_SAKATA COUNTER_COMCON_SAKATA(
.CLK(CLK),
.CLK25(CLK25),
.POR(POR),
.ADC_state(ADC_state),
.ENABLE(ENABLE),
.state(state_comcon),
.C_OUT1(C_OUT1)
);

SHIFT_REG_SAKATA SHIFT_REG_SAKATA(
.CLK(CLK),
.CLK25(CLK25),
.POR(POR),
.ADC_state(ADC_state),
.ENABLE(ENABLE),
.state(state_comcon),
.DATA(DATA[9:0]),
.S_OUT(S_OUT)
);

SELECT_SAKATA SELECT_SAKATA(
.CLK(CLK),
.CLK25(CLK25),
.POR(POR),
.ADC_state(ADC_state),
.ENABLE(ENABLE),
.state(state_comcon),
.TYPE(TYPE),
.C_OUT1(C_OUT1),
.S_OUT(S_OUT),
.OUT(OUT),
.ADDRESS(ADDRESS[7:0])
);

endmodule
