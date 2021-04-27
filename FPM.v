`include "FPA.v"
`include "triArr.v"

module FPMul(input clk,input [31:0]I1,input [31:0]I2,output [31:0]out);
    wire [31:0]outbuff2;
    wire [31:0]A,B;
    Swap SW1(I1,I2,A,B);

    wire S1,S2;
    wire [7:0] E1,E2;
    wire [22:0] M1,M2;

    Split SP1(A,S1,E1,M1);
    Split SP2(B,S2,E2,M2);

    // Summing up the Exponents
    wire [31:0]Ednm,Eout,Eoutbuff,Eoutbuff1;
    wire  Carr;
    CLA CL1(clk,Ednm,Carr,{24'b0,E1},{24'b0,E2},1'b0); 
    CLA CL2(clk,Eout,Carr,Ednm,~(32'd127),1'b1);

    clockDelay #(13,32) cd1 (clk,Eout,Eoutbuff);    

    wire [31:0]N1,N2;
    wire [63:0]P,Pbuff;
    assign N1 = {|E1,M1};
    assign N2 = {|E2,M2};

    WallaceMul Wm(clk,N1,N2,P);

    clockDelay #(12,64) cd2 (clk,P,Pbuff);

    // A is is inf or NAN and B is not zero
    TriArr T1(A,&E1 & |B[30:0],outbuff2);

    // B is zero and A is Not INF or NAN
    TriArr T2(B,~(|B[30:0]) & ~&E1,outbuff2);

    // A is INF or NAN and B is zero
    TriArr T3({32{1'b1}},&E1 & ~(|B[30:0]),outbuff2);

    clockDelay #(25,32) cd4 (clk,outbuff2,out);

    //Case of overflow(no inf/NAN/zero/Denormal)
    wire [31:0]EoutShift;
    CLA CL3(clk,EoutShift,Carr,Eoutbuff,32'b1,1'b0);
    TriArr T4({S1^S2,EoutShift[7:0],Pbuff[46:24]},Pbuff[47] & ~(&E1 | ~(|B[30:0])),out);

    //Normal Case (no inf/NAN/zero/Denormal)
    clockDelay #(4,32) cd3 (clk,Eoutbuff,Eoutbuff1);
    TriArr T5({S1^S2,Eoutbuff1[7:0],Pbuff[45:23]},~Pbuff[47] & Pbuff[46] & ~(&E1 | ~(|B[30:0])),out);
endmodule