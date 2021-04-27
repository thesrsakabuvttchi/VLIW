`include "swap.v"
`include "Mul.v"
`include "shifters.v"
`include "split.v"

module FPAdder(input clk,input [31:0]I1,input [31:0]I2,output [31:0]out);
    wire [31:0]A,B;
    Swap SW(I1,I2,A,B);


    wire S1,S2,S1buff;
    wire [7:0] E1,E2,E1buff,E2buff;
    wire [22:0] M1,M2,M1buff,M2buff;

    clockDelay #(4,1) cd1 (clk,S1,S1buff);
    clockDelay #(4,8) cd2 (clk,E1,E1buff);
    clockDelay #(4,23) cd3 (clk,M1,M1buff);
    clockDelay #(4,8) cd4 (clk,E2,E2buff);
    clockDelay #(4,23) cd5 (clk,M2,M2buff);

    Split SP1(A,S1,E1,M1);
    Split SP2(B,S2,E2,M2);

    wire Carry;
    wire  [7:0]Ediff;
    wire [31:0]tmpDiff;
    CLA Cdiff(clk,tmpDiff,Carry,{24'b0,E1},~{24'b0,E2},1'b1);
    assign Ediff = E1 - E2;

    wire [31:0] N1,N2,N3;
    assign N1 = {|E1,M1};   //Reduction or handles zeroes
    assign N2 = {|E2,M2};   //and denormal numbers

    RightShift BS(N2,Ediff,N3);

    wire [31:0]N4;
    assign N4 = {32{S1^S2}}^N3;

    wire [31:0]Sum,Sumbuff;
    CLA C1(clk,Sum,Carry,N1,N4,S1^S2);

    reg [22:0] M3,tmp;
    reg [7:0] E3;

    integer i =0;
    reg [31:0]out;

    always @(Sum)
    begin
        if(Sum[24]==1'b1)
        begin
            M3 = Sum[23:1];
            E3 = E1buff + 1'b1;
        end
        else if(Sum[23]==1'b0)
        begin
            i = 1;
            while(Sum[23-i] == 1'b0)
            begin
                i = i+1;
            end 
            E3 = E1buff - i;
            tmp = Sum[22:0];
            M3 = tmp<<i;
        end
        else
        begin
            M3 = Sum[22:0];
            E3 = E1buff;
        end

        // Case for infinity
        if(&E1buff == 1'b1 && |M1buff == 1'b0)
            out = {S1buff,{8{1'b1}},23'b0};
        else if(|E1buff==1'b0 && |E2buff==1'b0)
            out = {S1buff,{8'b0},Sum[22:0]};
        //Handles normal + NaN 
        else 
            out = {S1buff,{8{|Sum}} & E3,M3}; // reduction or for 0 case
    end

endmodule

// module top;

//     reg [31:0] I1,I2;
//     wire [31:0]out;
//     integer i;
//     reg clk;
    
//     Adder A(clk,I1,I2,out);

//     initial 
//     begin
//         #0 clk = 0;
//         for(i=0;i<=40;i++)
//         begin
//             #5 clk = ~clk;
//         end
//     end
    
//     initial
//     begin
//         // 10000 - 8000
//         #0 I1=32'b01000110000111000100000000000000;I2=32'b11000101111110100000000000000000;

//         // 800 - 800
//         #10 I1=32'b01000101111110100000000000000000;I2=32'b11000101111110100000000000000000;

//         //1.234 + 63.201 = (supposed) 64.435 but gets 64.4349975586 because of floating point precision error
//         #10 I1=32'b00111111100111011111001110110110;I2=32'b01000010011111001100110111010011;

//         // 9.75 + 0.5625 = 10.3125
//         #10 I1={1'b0,{8'b10000010},23'b00111000000000000000000}; I2={1'b0,{8'b01111110},23'b00100000000000000000000};
//     end
//     initial
//     begin
//         $monitor($time, " A=%b B=%b\tC=%b\n",I1,I2,out);
//     end

// endmodule
