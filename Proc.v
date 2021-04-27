`include "FPM.v"
`include "LogicUnit.v"

module top;

    reg clk;                                
    integer j;

    reg [31:0]RF[31:0];                
    reg [31:0]Dmem[1023:0];       
    reg [32*6-1:0]Imem[255:0];    
    reg [32*6-1:0]NxIBuff,NxI;
    reg [31:0]NextPc;
    reg [5:0][31:0]Instructions;
    reg [31:0] AddIn1,AddIn2,AddInsBuff;
    wire [4:0]AddRegBuff;
    wire [31:0]AddOut;
    wire cout;
    reg [31:0] MulIn1,MulIn2,MulInsBuff;
    wire [4:0 ]MulRegBuff1,MulRegBuff2;
    wire [63:0]MulOut;
    reg [31:0] FPAIn1,FPAIn2,FPAInsBuff;
    wire [4:0] FPARegBuff;
    wire [31:0] FPAOut;
    reg [31:0] FPMIn1,FPMIn2,FPMInsBuff;
    wire [4:0] FPMRegBuff;
    wire [31:0] FPMOut;
    reg [31:0] LUIn1,LUIn2,LUInsBuff;
    wire [31:0] LUOut;
    wire [4:0]LURegBuff;
    reg [2:0]LUOpcBuff;
    reg [31:0] MemInsBuff,MemInsBuff2;
    reg [31:0] MemOut;

    CLA adder(clk,AddOut,cout,AddIn1,AddIn2,1'b0);
    clockDelay #(4,5) cda1(clk,AddInsBuff[27:23],AddRegBuff);
    WallaceMul multiplier(clk,MulIn1,MulIn2,MulOut);
    clockDelay #(13,5) cdm1(clk,MulInsBuff[27:23],MulRegBuff1);
    clockDelay #(13,5) cdm2(clk,MulInsBuff[22:18],MulRegBuff2);
    LogicUnit LU(clk,LUOpcBuff,LUIn1,LUIn2,LUOut);
    dff #(5) cdLU(clk,LUInsBuff[27:23],LURegBuff);
    FPMul FPM(clk,FPMIn1,FPMIn2,FPMOut);
    clockDelay #(4,5) cdFPM(clk,FPMInsBuff[27:23],FPMRegBuff); 
    FPAdder FPA(clk,FPAIn1,FPAIn2,FPAOut);
    clockDelay #(4,5) cdFPA(clk,FPAInsBuff[27:23],FPARegBuff);

    always @(posedge clk) 
    begin

        NxI = NxIBuff;              
        RF[31] = NextPc;
        NxIBuff = Imem[NextPc];
        NextPc = RF[31]+1;      
 
        Instructions = NxI;

        AddInsBuff = Instructions[0];
        AddIn1 <= RF[AddInsBuff[22:18]];
        AddIn2 <= RF[AddInsBuff[17:13]];
        MulInsBuff = Instructions[1];
        MulIn1 <= RF[MulInsBuff[17:13]];
        MulIn2 <= RF[MulInsBuff[12:8]];
        FPAInsBuff = Instructions[2];
        FPAIn1 <= RF[FPAInsBuff[22:18]];
        FPAIn2 <= RF[FPAInsBuff[17:13]];
        FPMInsBuff = Instructions[3];
        FPMIn1 <= RF[FPMInsBuff[22:18]];
        FPMIn2 <= RF[FPMInsBuff[17:13]];
        LUInsBuff = Instructions[4];
        LUIn1 <= RF[LUInsBuff[22:18]];
        LUIn2 <= RF[LUInsBuff[17:13]];
        LUOpcBuff <= LUInsBuff[31:29];
        MemInsBuff = MemInsBuff2;
        MemInsBuff2 = Instructions[5];
        if(MemInsBuff[31]==1'b0)
            MemOut <= MemInsBuff[24:0];
        else if(MemInsBuff[31:30]==2'b11)
            MemOut <= RF[MemInsBuff[29:25]];
        else if(MemInsBuff[31:30]==2'b10)
            MemOut <= Dmem[MemInsBuff[24:15]];
        else
            MemOut <= 0;
    end

    always @(clk) 
    begin

        RF[AddRegBuff] <= AddOut;        
        RF[MulRegBuff1] <= MulOut[63:32];
        RF[MulRegBuff2] <= MulOut[31:0];
        RF[FPARegBuff] <= FPAOut;
        RF[LURegBuff] <= LUOut;
        if(MemInsBuff[31]^MemInsBuff[30] == 1'b1)
            RF[MemInsBuff[29:25]] <= MemOut;
        else
            Dmem[MemInsBuff[24:15]] <= MemOut;
    end

    reg rst;                               
    integer i;                              
    always @(rst) 
    begin
        if(rst==1'b1)
            for(i=0;i<32;i=i+1)
                RF[i] = i;          
        NextPc = 32'd0;
    end

    initial
    begin
        #0 clk =1;
        for(j=0;j<100;j++)
            #5 clk=~clk;        
    end

    initial 
    begin
        #0 rst=1'b1; 
        #5 rst = 1'b0;   
    end

    initial 
    begin
        //reRw
    end

    integer ct;
    always @(RF[31]) 
    begin
        $display("#BEG",$time);
        for(ct=0;ct<32;ct++)
            $display(RF[ct]);
        $display("#END");
    end

endmodule