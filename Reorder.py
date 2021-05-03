import os
f = open('test.vsm','r')
asm = f.read()
f.close()

Adder = ["ADD","ADDC","SUB","SUBB"]
AdderOpc = ["0000","0100","1100","1000"]

Multiplier = ["MUL"]
MultiplierOpc = ["0000"]

FPA = ["FADD"]
FPAOpc = ["0000"]

FPM = ["FMUL"]
FPMOpc = ["0000"]

LogicUnit = ["AND","OR","NAND","NOR","XOR","XNOR","NOT","BLS"]
LogicUnitOpc = ["0000","0110","0100","1010","0010","1110","1000","1100"]

Mem = ["MOV","LDR","STR"]
MemOpc = ["01","10","11"]

Units = [Adder,Multiplier,FPA,FPM,LogicUnit,Mem]
UnitsOpc = [AdderOpc,MultiplierOpc,FPAOpc,FPMOpc,LogicUnitOpc,MemOpc]

Un = []
for i in Units:
    Un = Un+i
UnOp = []
for i in UnitsOpc:
    UnOp = UnOp+i
Opc = dict(zip(Un,UnOp))

def GetUnit(i):
    for j in Units:
        if(i in j):
            return(j)

Delay = dict(zip(Adder+Multiplier+FPA+FPM+LogicUnit+Mem,[5]*len(Adder)+[14]*len(Multiplier)+[5]*len(FPA)+[26]*len(FPM)+[1]*len(LogicUnit+[1]*len(Mem))))
Instructions = asm.split('\n')

Ins = []
regs = []
for i in Instructions:
    Ins.append(i.split(' ')[0])
    if(i.split(' ')[0] not in Mem):
        regs.append(i.split(' ')[1].split(','))
    else:
        if("#" in i.split(' ')[1]):
            regs.append(i.split(' ')[1].split(',')[:-1]+["R0"])
        else:
            regs.append(i.split(' ')[1].split(','))           

class Node:
    def __init__(self,Reg,ins):
        self.Reg = Reg
        self.Instruction = None
        self.InstructionAsWord = ins
        self.Delay = 0
        self.Parents = []
        self.Children = []
        self.WAWdeps = []
        self.WARdeps = []
        self.exc = False

    def add_child(self,child):
        self.Children.append(child)

    def add_parents(self,parents):
        self.Parents = parents

    def add_WAW(self,deps):
        if(type(deps)==list):
            self.WAWdeps.extend(deps)
        else:
            self.WAWdeps.append(deps)

    def add_WAR(self,deps):
        if(type(deps)==list):
            self.WARdeps.extend(deps)
        else:
            self.WARdeps.append(deps)

    def add_ins(self,ins):
        self.Instruction = ins
        self.Delay = Delay[ins]

    def print_node(self):
        print("Reg Name:",self.Reg)

BegNodeTable = [Node("R"+str(i),"") for i in range(32)]   
GlobalNodeTable = list(BegNodeTable)

for i in range(len(Ins)):
    if(Ins[i]!="MUL"):
        rparents = regs[i][1:]
    else:
        rparents = regs[i][2:]
    rname = regs[i][0]

    #Create Node and set parents, instruction
    N = Node(rname,Instructions[i])
    N.add_ins(Ins[i])
    N.add_parents(rparents)

    #Update the child for the parents
    for j in rparents:
        GlobalNodeTable[int(j[1:])].add_child(N)

    #Set WAWdeps to previous Node pointing to the register
    N.add_WAW(GlobalNodeTable[int(rname[1:])])
    if(Ins[i]=="MUL"):
        N.add_WAW(GlobalNodeTable[int(regs[i][1][1:])])

    #Set WARdeps to children of Node pointing to register
    N.add_WAR(GlobalNodeTable[int(rname[1:])].Children)
    if(Ins[i]=="MUL"):
        N.add_WAR(GlobalNodeTable[int(regs[i][1][1:])].Children)

    #Remove Cyclic WAR dependencies (if source & dest are same reg)
    while(N in N.WARdeps):
        N.WARdeps.remove(N)

    #Swap the new node with the old one
    GlobalNodeTable[int(rname[1:])] = N 
    if(Ins[i]=="MUL"):
        GlobalNodeTable[int(regs[i][1][1:])] = N         

NextLv = []
Packet = []
PacketedIns = []
while len(BegNodeTable)!=0:
    #degue first element of the node table
    leader = BegNodeTable[0]
    BegNodeTable = BegNodeTable[1:]

    #Check if the unit (ADD/MUL/FPA/FPM/LU/MEM) is free for that clock cycle
    UnitFree = all([not(GetUnit(i.split(' ')[0]) == GetUnit(leader.Instruction)) for i in Packet])

    WAWCleared = all([((i.Delay==0)) for i in leader.WAWdeps])
    WARCleared = all([i.exc for i in leader.WARdeps])

    #if the instruction is executable, set exc and print it
    if(leader.Parents==[] and leader.Instruction!=None and leader.exc==False and WAWCleared and WARCleared and UnitFree):
        leader.exc = True
        print(leader.InstructionAsWord,"("+str(leader.Delay)+")",end="\t")
        Packet.append(leader.InstructionAsWord)


    #if WAW,WAR is not cleared or Unit is Busy just append the leader as is
    if(leader.Parents == [] and ((not WAWCleared) or (not WARCleared) or (not UnitFree))):
        NextLv.append(leader)
    #if the leader is executable (no parent dependency) and is not a zero delay node decrease delay
    #Then append back to waiting queue
    elif(leader.Parents == [] and leader.Delay!=0):
        leader.Delay = leader.Delay-1
        if(leader.Delay>0):
            NextLv.append(leader)


    #if leader has completed push children
    #and delink leader from the Parent's list of it's children            
    if(leader.Delay==0):
        NextLv.extend(leader.Children)
        for i in leader.Children:
            i.Parents.remove(leader.Reg)

    if(BegNodeTable==[]):
        BegNodeTable = list(set(NextLv))
        NextLv = []
        PacketedIns.append(Packet)
        Packet = []
        print()

#First instruction is NOP because of dummy registers
PacketedIns = PacketedIns[1:]

#Reorder instruction packet based of funtional unit {Mem|Logic|FPM|FPA|Mul|Add}
RepackedIns = []
for i in PacketedIns:
    repack = ["NOP"]*6
    for j in i:
        for k in range(6):
            if(j.split(' ')[0] in Units[k]):
                repack[k] = j
    RepackedIns.append(repack)

RepackedIns = [i[::-1] for i in RepackedIns]

for i in RepackedIns:
    print(i)

def ToBin(reg,numDig=5):
    binNum = ""
    while(reg>0):
        binNum = binNum + str(reg%2)
        reg = int(reg/2)
    binNum = binNum + "0"*(numDig-len(binNum))
    return(binNum[::-1])

BinPackIns = []

#converts packets into binary instructions
for i in RepackedIns:
    BinPack = []
    for j in i:
        BinIns = ""
        if(j!="NOP"):
            ins = Opc[j.split(" ")[0]]
            if(j.split(" ")[0] not in Mem):
                regs = "".join([ToBin(int(k[1:])) for k in j.split(" ")[1].split(",")])
            else:
                tmp = [int(k[1:]) for k in j.split(" ")[1].split(",")]
                if(ins == "01"):
                    regs = str(ToBin(tmp[0]))+str(ToBin(tmp[1],25))
                else:
                    regs = str(ToBin(tmp[0]))+str(ToBin(tmp[1],10))
            BinIns = ins+regs
            BinIns = BinIns + "0"*(32-len(BinIns))
        else:
            BinIns = "0"*32
        BinPack.append(BinIns)
    BinPackIns.append(BinPack)   

BinPackIns = ["192'b"+("".join(i)) for i in BinPackIns]
BinPackIns = ["InstructionMem[%i]="%i + BinPackIns[i]+";" for i in range(len(BinPackIns))]

f = open('Processor.v','r')
tb = f.read()
new_tb = "".join([tb[:tb.find("//pyc_pushcode")],"\n\t\t".join(BinPackIns),tb[tb.find("//pyc_pushcode"):]])
f.close()

f = open('NewProcessor.v','w')
f.write(new_tb)
f.close()

print("Generated new testbench file..........\n")

if(os.name!='posix'):
    print("Unsupported OS!")
    exit()

print("Compiling testbench...........\n")
os.system("iverilog NewProcessor.v")

print("Running testbench............\n")
os.system("./a.out > output.txt")

print("Parsing output................\n")
f = open("output.txt")
dump = f.read()
dump = dump.split("#BEG")
dump = [i.split('#END')[0].split('\n') for i in dump]
dump = dump[1:]

newDump = [dump[1]]
for i in range(1,len(dump)):
    if((dump[i][1:-2])!=(dump[i-1][1:-2])):
        newDump.append(dump[i])

for i in range(len(newDump)):
    for j in range(len(newDump[i])-1):
        newDump[i][j] = int(newDump[i][j])

print("Time \t PC \t Register Values")

for i in newDump:
    i = i[:-1]
    print(i[0],"\t",i[-1],"\t",i[1:-1])

os.system("rm NewProcessor.v a.out output.txt")