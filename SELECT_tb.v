`timescale 1ns/1ns

module SELECT_tb;
reg CLK,ADC_STATE,POR,ENABLE;
reg C_OUT1,S_OUT;
reg [1:0] TYPE;
reg [7:0] ADDRESS;
wire OUT;
wire [2:0] state;

initial begin
    C_OUT1 = 1'b1;
    ADDRESS = 8'b1111_0011;
    TYPE = 2'b11;
    S_OUT = 1'b0;
end

wire [3:0] cnt2;
wire CLK5;
assign CLK5 = (cnt2 == 4'd1);
counter_4bit CLK5_divider(.CLK(CLK),.POR(POR),.RST(ADC_STATE),.COUNT_UP(1'b1),.PERIOD(4'd2),.COUNT(cnt2));

SELECT SELECT(.CLK(CLK),.CLK5(CLK5),.POR(POR),.ADC_STATE(ADC_STATE),.C_OUT1(C_OUT1),
              .S_OUT(S_OUT),.TYPE(TYPE),.ENABLE(ENABLE),.ADDRESS(ADDRESS),.OUT(OUT),.state(state));


always begin
     CLK = 1'b1;
#50 CLK = 1'b0;
#50;
end

initial fork
          POR = 1'b0;
#300   POR = 1'b1;
join

initial fork
          ENABLE = 1'b0;
#2000   ENABLE = 1'b1;
#28000  ENABLE = 1'b0;
join

initial fork
          ADC_STATE = 1'b1;
#1000   ADC_STATE = 1'b0;
#450000 ADC_STATE = 1'b1;
join

initial begin
    $dumpfile("SELECT_tb.vcd");
    $dumpvars(0, SELECT_tb);
    // テストの内容
    #500000;  // 適切な時間待つ
    $finish;  // シミュレーション終了
end

endmodule
