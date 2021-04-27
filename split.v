module Split(input [31:0]A, output sign, output [7:0]exp, output [22:0]man);
    assign sign = A[31];
    assign exp = A [30:23];
    assign man = A[22:0];
endmodule

