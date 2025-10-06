module offset_calib (
    input  CLK,POR,RST,
    input  CALIB_ON,COMPARATOR,C_SIDE,
    input  [7:0] count_COMP_CLK,
    input  [1:0] state,
    output reg [4:0] SW1,SW2
 );


reg [4:0] SW_DATA1,SW_DATA2;
reg [2:0] cnt;

always  @(posedge CLK or negedge POR )begin
    if(!POR)
     cnt <= 3'b000;
     else if(RST)
     cnt <= 3'b000;
     else if(state == 2'b00)
     cnt <= 3'b000;
    else if((CALIB_ON)&&( count_COMP_CLK == 8'd1)&&(cnt <= 3'd7))
        cnt <= cnt+3'd1;
    else
     cnt <= cnt;
end

always  @(posedge CLK or negedge POR )begin
    if(!POR)
     SW_DATA1 <= 5'b11111;
     else if(RST)
     SW_DATA1 <= 5'b11111;
    else if ((CALIB_ON)&&(cnt ==3'd1))
     SW_DATA1 <= 5'b11111;
    else if((CALIB_ON)&&(cnt >= 3'd2)&&(cnt <= 3'd6)&&(count_COMP_CLK == 8'd14)&&(C_SIDE))
     SW_DATA1[3'd6-cnt] <= !COMPARATOR;
    else
     SW_DATA1 <= SW_DATA1;
end

always  @(posedge CLK or negedge POR )begin
    if(!POR)
     SW_DATA2 <= 5'b11111;
     else if(RST)
     SW_DATA2 <= 5'b11111;
    else if ((CALIB_ON)&&(cnt ==3'd1))
     SW_DATA2 <= 5'b11111;
    else if((CALIB_ON)&&(cnt >= 3'd2)&&(cnt <= 3'd6)&&(count_COMP_CLK == 8'd14)&&(!C_SIDE))
     SW_DATA2[3'd6-cnt] <= COMPARATOR;
    else
     SW_DATA2 <= SW_DATA2;
end

always  @(posedge CLK or negedge POR )begin
    if(!POR)
     SW1 <= 5'b11111;
     else if(RST)
     SW1 <= 5'b11111;
     else if((state == 2'b00)&&(cnt == 3'd1))
     SW1 <= 5'b11111;
     else if(cnt == 3'd0)
     SW1 <= SW_DATA1[4:0];
     else if((CALIB_ON)&&(C_SIDE))
        case (cnt)
          3'd2 : SW1 <= {1'b0, {4{1'b1}} };
          3'd3 : SW1 <= {SW_DATA1[4], 1'b0, {3{1'b1}}};
          3'd4 : SW1 <= {SW_DATA1[4:3], 1'b0, {2{1'b1}}};
          3'd5 : SW1 <= {SW_DATA1[4:2], 1'b0,1'b1};
          3'd6 : SW1 <= {SW_DATA1[4:1], 1'b0};
          3'd7 : SW1 <= SW_DATA1[4:0];
          default : SW1 <= SW_DATA1[4:0];
        endcase
    else
     SW1 <= SW_DATA1[4:0];
end


always  @(posedge CLK or negedge POR )begin
    if(!POR)
     SW2 <= 5'b11111;
     else if(RST)
     SW2 <= 5'b11111;
     else if((state == 2'b00)&&(cnt == 3'd1))
     SW2 <= 5'b11111;
     else if(cnt == 3'd0)
     SW2 <= SW_DATA2[4:0];
    else if((CALIB_ON)&&(!C_SIDE))
        case (cnt)
          3'd2 : SW2 <= {1'b0, {4{1'b1}} };
          3'd3 : SW2 <= {SW_DATA2[4], 1'b0, {3{1'b1}}};
          3'd4 : SW2 <= {SW_DATA2[4:3], 1'b0, {2{1'b1}}};
          3'd5 : SW2 <= {SW_DATA2[4:2], 1'b0,1'b1};
          3'd6 : SW2 <= {SW_DATA2[4:1], 1'b0};
          3'd7 : SW2 <= SW_DATA2[4:0];
          
          default : SW2 <= SW_DATA2[4:0];
        endcase
    else
     SW2 <= SW_DATA2[4:0];
end


endmodule
