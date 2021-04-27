module Swap(input [31:0]in1, input [31:0]in2, output reg [31:0]out1, output reg [31:0]out2);

    always @*
    begin
        if(in2[30:0]>in1[30:0])
        begin
            out2 = in1;
            out1 = in2;
        end
        else
        begin
            out1 = in1;
            out2 = in2;
        end
    end

endmodule
