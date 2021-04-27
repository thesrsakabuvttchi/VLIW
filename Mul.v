//9 Stage pipeline

`include "Adder.v"

module mul(input [31:0]a,input [31:0]b, output [31:0][63:0]out);
    genvar i;
    generate
        for(i=0;i<32;i=i+1) begin
           assign out[i] = (a & {64{b[i]}})<<i;
        end
    endgenerate 
endmodule

module addArr#(parameter SIZE = 64) (input [SIZE-1:0]a, input [SIZE-1:0]b, input [SIZE-1:0]cin, output [SIZE-1:0]sum, output [SIZE-1:0]c);
    genvar i;
    generate
        for (i = 0;i<SIZE-1;i=i+1) begin
            full_adder FA1(a[i],b[i],cin[i],sum[i],c[i+1]);
        end
        assign sum[SIZE-1] = a[SIZE-1]^b[SIZE-1]^cin[SIZE-1];
        assign c[0] = 1'b0;
    endgenerate    
endmodule

module full_adder(input a, input b, input cin, output sum, output cout);
    assign sum = a^b^cin;
    assign cout =(a&b)|(a&cin)|(b&cin);
endmodule

module carrySave #(parameter N=32, parameter M=22) (input [(N-1):0][63:0]a,output [(M-1):0][63:0]out);
    genvar i,j;
    integer ct=0;
    generate
        for (i = 0;i<N/3;i=i+1) begin
            addArr A1(a[3*i],a[3*i+1],a[3*i+2],out[2*i],out[2*i+1]);
        end
        for (j=1;j<=N%3;j=j+1) begin
            assign out[M-j] = a[N-j]; 
        end
    endgenerate
endmodule

module adderTree (input clk,input [31:0][63:0]a, output [1:0][63:0]out);

    wire [21:0][63:0]tmp1,buff1;
    carrySave #(32,22) CS1 (a,tmp1);

    dff #(22*64) DFF1 (clk,tmp1,buff1);

    wire [14:0][63:0]tmp2,buff2;
    carrySave #(22,15) CS2 (buff1,tmp2);

    dff #(15*64) DFF2 (clk,tmp2,buff2);

    wire [9:0][63:0]tmp3,buff3;
    carrySave #(15,10) CS3 (buff2,tmp3);

    dff #(10*64) DFF3 (clk,tmp3,buff3);

    wire [6:0][63:0]tmp4,buff4;
    carrySave #(10,7) CS4 (buff3,tmp4);

    dff #(7*64) DFF4 (clk,tmp4,buff4);

    wire [4:0][63:0]tmp5,buff5;
    carrySave #(7,5) CS5 (buff4,tmp5);

    dff #(5*64) DFF5 (clk,tmp5,buff5);

    wire [3:0][63:0]tmp6,buff6;
    carrySave #(5,4) CS6 (buff5,tmp6);

    dff #(4*64) DFF6 (clk,tmp6,buff6);

    wire [2:0][63:0]tmp7,buff7;
    carrySave #(4,3) CS7 (buff6,tmp7);

    dff #(3*64) DFF7 (clk,tmp7,buff7);

    wire [1:0][63:0]tmp8;
    carrySave #(3,2) CS8 (buff7,tmp8);

    dff #(2*64) DFF8 (clk,tmp8,out);

endmodule

module WallaceMul(input clk,input [31:0]A,input [31:0]B,output [63:0]C);

    wire [31:0][63:0]partial,tmp;
    wire [1:0][63:0]out;
    wire cout;
    mul M1(A,B,tmp);

    dff #(2048) DFF1 (clk,tmp,partial);

    adderTree At1 (clk,partial,out);

    CLA64 C64(clk,out[1],out[0],1'b0,C,cout);

endmodule
