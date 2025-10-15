//Verilog HDL for "BMI_digital_sakata_v1", "COUNTER_COMCON" "functional"

module COUNTER_COMCON(
       input CLK, CLK5, POR, ADC_STATE,
       input [2:0] state,
       output reg C_OUT1
);

always@(posedge CLK or negedge POR)begin
         if (!POR)
           C_OUT1 <= 1'b0;
         else if (state == 3'b001)
           C_OUT1 <= !C_OUT1;  // トグル動作
         else if (state != 3'b001)
           C_OUT1 <= 1'b0;
         else
           C_OUT1 <= C_OUT1;
end


endmodule
