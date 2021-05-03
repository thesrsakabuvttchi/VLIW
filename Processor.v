`include "FPM.v"
`include "LogicUnit.v"

module top;

    reg clk;                                //Clock generator for entire circuit
    integer j;

    reg [31:0]RegFile[31:0];                //Register File of processor
    /*
    R0 :- Special register always 0
    R31 :- PC
    R30 :- CPSR bits NZCV (0 to 3)
    R1 to R30 :- General purpose registers
    */
    reg [31:0]DataMem[1023:0];       //Data Memory (4KB)
    reg [32*6-1:0]InstructionMem[255:0];    //Instruction Memory (6KB)

    reg [32*6-1:0]NextInsBuff,NextIns;
    reg [31:0]NextPc;
    reg [5:0][31:0]Instructions;

/*
..........................................................................................................................
Adder
..........................................................................................................................
*/
    reg [31:0] AddIn1,AddIn2,AddInsBuff;
    wire [4:0]AddRegBuff;
    wire [31:0]AddOut;
    wire cout;

    CLA adder(clk,AddOut,cout,AddIn1,(AddIn2^{32{AddInsBuff[31]}}),AddInsBuff[30]);
    clockDelay #(4,5) cda1(clk,AddInsBuff[27:23],AddRegBuff);

/*
..........................................................................................................................
Multiplier
..........................................................................................................................
*/

    reg [31:0] MulIn1,MulIn2,MulInsBuff;
    wire [4:0 ]MulRegBuff1,MulRegBuff2;
    wire [63:0]MulOut;

    WallaceMul multiplier(clk,MulIn1,MulIn2,MulOut);
    clockDelay #(13,5) cdm1(clk,MulInsBuff[27:23],MulRegBuff1);
    clockDelay #(13,5) cdm2(clk,MulInsBuff[22:18],MulRegBuff2);

/*
..........................................................................................................................
FPA
..........................................................................................................................
*/
    reg [31:0] FPAIn1,FPAIn2,FPAInsBuff;
    wire [4:0] FPARegBuff;
    wire [31:0] FPAOut;

    FPAdder FPA(clk,FPAIn1,FPAIn2,FPAOut);
    clockDelay #(4,5) cdFPA(clk,FPAInsBuff[27:23],FPARegBuff);

/*
..........................................................................................................................
FPM
..........................................................................................................................
*/
    reg [31:0] FPMIn1,FPMIn2,FPMInsBuff;
    wire [4:0] FPMRegBuff;
    wire [31:0] FPMOut;

    FPMul FPM(clk,FPMIn1,FPMIn2,FPMOut);
    clockDelay #(25,5) cdFPM(clk,FPMInsBuff[27:23],FPMRegBuff); 

/*
..........................................................................................................................
Logic Unit
..........................................................................................................................
*/
    reg [31:0] LUIn1,LUIn2,LUInsBuff;
    wire [31:0] LUOut;
    wire [4:0]LURegBuff;
    reg [2:0]LUOpcBuff;

    LogicUnit LU(clk,LUOpcBuff,LUIn1,LUIn2,LUOut);
    dff #(5) cdLU(clk,LUInsBuff[27:23],LURegBuff);

/*
..........................................................................................................................
Memory Acess Unit
..........................................................................................................................
*/
    reg [31:0] MemInsBuff,MemInsBuff2;
    reg [31:0] MemOut;


    always @(posedge clk) 
    begin
/*
..........................................................................................................................
Instruction fetch module
..........................................................................................................................
*/
        NextIns = NextInsBuff;              //Dff to hold NextIns for 1 clock cycle(For Pipeline)
        RegFile[31] = NextPc;
        NextInsBuff = InstructionMem[NextPc];
        NextPc = RegFile[31]+1;      
/*
..........................................................................................................................
Instruction decode module and Execute module
..........................................................................................................................
*/  
        Instructions = NextIns;

        //Addition
        AddInsBuff = Instructions[0];
        AddIn1 <= RegFile[AddInsBuff[22:18]];
        AddIn2 <= RegFile[AddInsBuff[17:13]];

        //Multiplication
        MulInsBuff = Instructions[1];
        MulIn1 <= RegFile[MulInsBuff[17:13]];
        MulIn2 <= RegFile[MulInsBuff[12:8]];

        //FPA
        FPAInsBuff = Instructions[2];
        FPAIn1 <= RegFile[FPAInsBuff[22:18]];
        FPAIn2 <= RegFile[FPAInsBuff[17:13]];

        //FPM
        FPMInsBuff = Instructions[3];
        FPMIn1 <= RegFile[FPMInsBuff[22:18]];
        FPMIn2 <= RegFile[FPMInsBuff[17:13]];

        //Logic Unit
        LUInsBuff = Instructions[4];
        LUIn1 <= RegFile[LUInsBuff[22:18]];
        LUIn2 <= RegFile[LUInsBuff[17:13]];
        LUOpcBuff <= LUInsBuff[31:29];

        //Memory Acess
        MemInsBuff = MemInsBuff2;
        MemInsBuff2 = Instructions[5];
        if(MemInsBuff[31]==1'b0)
            MemOut <= MemInsBuff[24:0];
        else if(MemInsBuff[31:30]==2'b11)
            MemOut <= RegFile[MemInsBuff[29:25]];
        else if(MemInsBuff[31:30]==2'b10)
            MemOut <= DataMem[MemInsBuff[24:15]];
        else
            MemOut <= 0;
    end

    always @(clk) 
    begin
/*
..........................................................................................................................
Write Back module
..........................................................................................................................
*/  
        RegFile[AddRegBuff] <= AddOut;        

        RegFile[MulRegBuff1] <= MulOut[63:32];
        RegFile[MulRegBuff2] <= MulOut[31:0];

        RegFile[FPARegBuff] <= FPAOut;

        RegFile[FPMRegBuff] <= FPMOut;

        RegFile[LURegBuff] <= LUOut;

        if(MemInsBuff[31]^MemInsBuff[30] == 1'b1)
            RegFile[MemInsBuff[29:25]] <= MemOut;
        else
            DataMem[MemInsBuff[24:15]] <= MemOut;
    end

    reg rst;                                //Take PC to 0 (start of Instruction mem
    integer i;                              //Integer to use in resets
    always @(rst) 
    begin
        if(rst==1'b1)
            for(i=0;i<32;i=i+1)
                RegFile[i] = i;          //Reset every reg to 0 
        NextPc = 32'd0;
    end

    always @(rst) 
    begin
        if(rst==1'b1)
            for(i=0;i<1024;i=i+1)
                DataMem[i] = i;          //Reset every reg to 0 
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
        //pyc_pushcode
    end

    integer ct;
    always @(RegFile[31]) 
    begin
        $display("#BEG",$time);
        for(ct=0;ct<32;ct++)
            $display(RegFile[ct]);
        $display("#END");
    end

endmodule