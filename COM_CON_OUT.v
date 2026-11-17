//COM_CON_OUT for multi device + new 10bit ADC

module COM_CON_OUT(
   input CLK,POR,S_Bias_OPT,S_Bias_ELE,OPERATE_OPT,OPERATE_ELE,
   input [9:0] DATA_OPT,DATA_ELE,
   input [7:0] ADDRESS,
   output COM_EN_OPT, COM_EN_ELE,
   output OUT
);

wire SERIAL_OPT, SERIAL_ELE;


COM_CON_TOP COM_CON_OPT(
.CLK(CLK),
.POR(POR),
.ADC_state(S_Bias_OPT),
.DATA(DATA_OPT[9:0]),
.OPERATE(OPERATE_OPT),
.TYPE(1'b0),
.ADDRESS(ADDRESS[7:0]),
.def_delay(10'd000),
.ENABLE(COM_EN_OPT),
.OUT(SERIAL_OPT)
);

COM_CON_TOP COM_CON_ELE(
.CLK(CLK),
.POR(POR),
.ADC_state(S_Bias_ELE),
.DATA(DATA_ELE[9:0]),
.OPERATE(OPERATE_ELE),
.TYPE(1'b1)
,.ADDRESS(ADDRESS[7:0]),
.def_delay(10'd250),
.ENABLE(COM_EN_ELE),
.OUT(SERIAL_ELE)
);

SELECT_2in SELECT_COMCON(
.CLK(CLK),
.SEL1(COM_EN_OPT),
.SEL2(COM_EN_ELE),
.IN1(SERIAL_OPT),
.IN2(SERIAL_ELE),
.POR(POR),
.RST((S_Bias_OPT == 1'b1) && (S_Bias_ELE == 1'b1)),
.OUT(OUT)
);

endmodule
