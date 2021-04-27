import os
f = open('test.vss','r')
asm = f.read()
f.close()

Units = [['ADD', 'ADDC', 'SUB', 'SUBB'], ['MUL'], ['FADD'], ['FMUL'], ['AND', 'OR', 'NAND', 'NOR', 'XOR', 'XNOR', 'NOT', 'NEG'], ['MOV', 'LDR', 'STR']]
UnitsOpc = [['0000', '0100', '1100', '1000'], ['0000'], ['0000'], ['0000'], ['0000', '0110', '0100', '1010', '0010', '1110', '1000', '1100'], ['01', '10', '11']]
Opc = {'ADD': '0000','ADDC': '0100', 'SUB': '1100', 'SUBB': '1000', 'MUL': '0000', 'FADD': '0000', 'FMUL': '0000', 'AND': '0000', 'OR': '0110', 'NAND': '0100', 'NOR': '1010', 'XOR': '0010', 'XNOR': '1110', 'NOT': '1000', 'NEG': '1100', 'MOV': '01', 'LDR': '10', 'STR': '11'}
Delay = {'ADD': 5, 'ADDC': 5, 'SUB': 5, 'SUBB': 5, 'MUL': 14, 'FADD': 5, 'FMUL': 26, 'AND': 1, 'OR': 1, 'NAND': 1, 'NOR': 1, 'XOR': 1, 'XNOR': 1, 'NOT': 1, 'NEG': 1, 'MOV': 1, 'LDR': 1, 'STR': 1}

Instructions = asm.split('\n')

RepackedIns = [i.split('; ') for i in Instructions]
print(RepackedIns)

def ToBin(reg,numDig=5):
    binNum = ""
    while(reg>0):
        binNum = binNum + str(reg%2)
        reg = int(reg/2)
    binNum = binNum + "0"*(numDig-len(binNum))
    return(binNum[::-1])

Bins = []

#converts packets into binary instructions
for i in RepackedIns:
    BinPack = []
    for j in i:
        BinIns = ""
        if(j!="NOP"):
            ins = Opc[j.split(" ")[0]]
            if(j.split(" ")[0] not in ["MOV","LDR","STR"]):
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
    Bins.append(BinPack)   

Bins = ["192'b"+("".join(i)) for i in Bins]
Bins = ["Imem[%i]="%i + Bins[i]+";" for i in range(len(Bins))]

f = open('Proc.v','r')
tb = f.read()
new_tb = "".join([tb[:tb.find("//reRw")],"\n\t\t".join(Bins),tb[tb.find("//reRw"):]])
f.close()

f = open('Nproc.v','w')
f.write(new_tb)
f.close()

print("."*80,"\n")

if(os.name!='posix'):
    print("Unsupported OS!")
    exit()

print(".."*80,"\n")
os.system("iverilog Nproc.v")

print("..."*80,"\n")
os.system("./a.out > output.txt")

print("...."*80,"\n")
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

print("Register Values")

for i in newDump:
    i = i[:-1]
    print(i[1:-1])

os.system("rm Nproc.v a.out output.txt")