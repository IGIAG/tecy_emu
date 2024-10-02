import std.stdio;
import std.file;

ushort program_counter = 0;

byte[4] registers = [0,0,0,0];

ubyte[] program_memory;

byte[4000] memory;

bool halt = false;

void main(string[] args)
{
	program_memory = cast(byte[])std.file.read(args[1]);
	writefln("loaded %s program bytes",program_memory.length);
	writefln("%s",program_memory);

	//Since the emulator loads 2 words at a time, must get 1 byte of padding
	program_memory ~= 0;

	while(!halt){
		step();
		writefln("Registers: %s",registers);
	}

}

void step(){
	//Load the 2 bytes and check if the instruction specified in the first byte uses 1 or 2 bytes
	ushort word = program_memory[program_counter] << 8 | program_memory[program_counter + 1];
	bool is_double_size = (word >> 15) == 1;
	byte immed = program_memory[program_counter + 1];
	//Increment the instruction register an appropriate amount
	program_counter++;
	if(is_double_size){program_counter++;}
	
	ubyte opcode = word >> 12;
	ubyte Rd = ((word >> 10) & 0b00000011);
	ubyte Rs = ((word >> 8) & 0b00000011);
	writefln("--\nEXECUTED INSTRUCTION :\n WORD: %b \n OPCODE: %b \n RD: %b \n RS: %b",word,opcode,Rd,Rs);
	if(is_double_size){
		writefln("IMMED: %b",immed);
	}
	writeln("--");
	switch (opcode) {
		case 0: //AND Rd,Rs - Rd = Rd AND Rs
			registers[Rd] = registers[Rd] & registers[Rs];
			break;
		case 1: //OR Rd,Rs - Rd = Rd OR Rs
			registers[Rd] = registers[Rd] | registers[Rs];
			break;
		case 2: //ADD Rd,Rs - Rd = Rd + Rs
			registers[Rd] = cast(byte)(registers[Rd] + registers[Rs]); //TODO: Add flags for overflow
			break;
		case 3: //SUB Rd,Rs - Rd = Rd - Rs
			registers[Rd] = cast(byte)(registers[Rd] - registers[Rs]); //TODO: Add flags for underflow
			break;
		case 4: //LW Rd,(Rs) - Rd = Mem(Rs)
			registers[Rd] = memory[registers[Rs]];
			break;
		case 5: //SW Rd,(Rs) - Mem(Rs) = Rd
			memory[registers[Rs]] = registers[Rd];
			break;
		case 6: //MOV Rd,Rs - Rd = Rs
			registers[Rd] = registers[Rs];
			break;
		case 7: //NOP
			//Do nothing i guess? This man just took a break before deciding to make double sized instructions
			break;
		case 8: //JEQ Rd,immed - if Rd = 0 -> PC = immed
			if(registers[Rd] == 0){
				program_counter = immed;
			}
			break;
		case 9://JNE Rd,immed - if Rd != 0 -> PC = immed
			if(registers[Rd] != 0){
				program_counter = immed;
			}
			break;
		case 10://JGT Rd,immed - if Rd > 0 -> PC = immed
			if(registers[Rd] > 0){
				program_counter = immed;
			}
			break;
		case 11://JLT Rd,immed - if Rd < 0 -> PC = immed
			if(registers[Rd] < 0){
				program_counter = immed;
			}
			break;
		case 12: //LW Rd,immed - Rd = Mem(immed)
			registers[Rd] = memory[immed];
			break;
		case 13: //SW Rd,immed - Mem(immed) = Rd
			memory[immed] = registers[Rd];
			break;
		case 14: //LI Rd,immed - Rd = immed
			registers[Rd] = immed;
			break;
		case 15: //JMP immed - PC = immed
			if(immed == program_counter - 2){
				writefln("PC AT LOOPING PC: %s IMMED: %s - HALTING",program_counter,immed); //Just a basic halt if in a pointless loop
				halt = true;
			}
			program_counter = immed;
			break;
		default:
			//Some bad shit happened!
			return;
	}

}