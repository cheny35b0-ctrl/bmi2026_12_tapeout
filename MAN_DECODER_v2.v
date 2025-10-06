module MAN_DECODER_v2(
    input MAN,
    input POR,RST,
    output reg DATA_OUT,NOR1,NOR2,
    output wire CLK_OUT

);

reg first_negedge_ignored;
//posedge & negedge circuit 
//reg NOR1,NOR2;

always @(posedge POR)begin
    first_negedge_ignored <= 1'b1;
end

always @(posedge MAN or negedge POR) begin
    if (!POR) 
        first_negedge_ignored <= 1'b1;  
    else 
        first_negedge_ignored <= 1'b0;  
    
end
always@(posedge MAN or negedge POR or negedge RST)begin
    if(!POR)
     NOR1 <= 1'b0;
    else if(!RST)
     NOR1 <= 1'b0;
    else
     NOR1 <= 1'b1;
end

always@(negedge MAN or negedge POR or negedge RST)begin
    if(!POR)
     NOR2 <= 1'b0;
    else if(!RST)
     NOR2 <= 1'b0;
    else if (first_negedge_ignored)
     NOR2<=1'b0;
    else
     NOR2 <= 1'b1;
end

//CLK_OUT
wire OR = NOR1 || NOR2;
assign CLK_OUT = !OR;

//DATA_OUT
always@(negedge CLK_OUT or negedge POR)begin
    if(!POR)
     DATA_OUT <= 1'b0;
    else
     DATA_OUT <= MAN;
end

endmodule



