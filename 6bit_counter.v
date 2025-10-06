module COUNTER(
    input CLK, ADC_state,
    input POR, //asynchronous reset
    output reg C_OUT1, C_OUT6,
    output CNT4, CNT128,CNT124

// for testbench
/*
    output reg [2:0] cnt4,
    output reg [8:0] cnt128,
    output reg EN,C_OUT5,
    output CNT64
*/
);

// for nomal use

reg [2:0] cnt4;
reg [8:0] cnt128;
reg EN;
reg C_OUT5;
wire CNT64 = (cnt128==9'd63);

//always use
assign CNT4 = (cnt4==3'd3);
assign CNT128 = (cnt128==9'd127); //C_OUT6 generation signal
assign CNT124 = (cnt128==9'd123); //enable signal for shift register


//for testbench
//assign CNT64 = (cnt128==9'd63);




//control block//
always@(posedge CLK or negedge POR)begin
    if(!POR)
     EN <= 1'b0;
    else if(ADC_state)
     EN <= 1'b0;
    else if((ADC_state==1'b0) && (C_OUT5==1'b1) && (C_OUT6==1'b1))
     EN <= 1'b0;
    else
     EN <= 1'b1;
end

//count block//

//CNT4 generation//
always@(posedge CLK or negedge POR)begin
    if(!POR)
     cnt4 <= 3'b0;
    else if(ADC_state)
     cnt4 <= 3'b0;
    else if(CNT4)
     cnt4 <= 3'b0;
     else if(EN)
      cnt4 <= cnt4 + 1;
    else
      cnt4 <= cnt4;
end

//CNT128 generation//
always@(posedge CLK or negedge POR)begin
    if(!POR)
     cnt128 <= 9'b0;
    else if(ADC_state)
     cnt128 <= 9'b0;
    else if(CNT128)
     cnt128 <= 9'b0;
     else if(EN)
      cnt128 <= cnt128 + 1;
    else
      cnt128 <= cnt128;
end

//C_OUT1 generation
always@(posedge CLK or negedge POR)begin
    if(!POR)
      C_OUT1 <= 1'b0;
    else if(ADC_state)
      C_OUT1 <= 1'b0;
    else if(CNT4)
       //C_OUT1 <= DELAY;
       C_OUT1 <= !C_OUT1; 
    else
       C_OUT1 <= C_OUT1;
end

//C_OUT5 generation//
always@(posedge CLK or negedge POR)begin
    if(!POR)
       C_OUT5 <= 1'b0;
    else if(ADC_state)
       C_OUT5 <= 1'b0;
    else if(CNT64 | CNT128)
       C_OUT5 <= !C_OUT5;
    else
       C_OUT5 <= C_OUT5;
end

//C_OUT6 generation//
always@(posedge CLK or negedge POR)begin
    if(!POR)
       C_OUT6 <= 1'b0;
    else if(ADC_state)
       C_OUT6 <= 1'b0;   
    else if(CNT128)
       C_OUT6 <= !C_OUT6;
    else
       C_OUT6 <= C_OUT6;
end

endmodule
