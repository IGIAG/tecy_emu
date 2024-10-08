import std.stdio;
import std.file;
import std.algorithm : canFind;
import core.thread;
import std.conv : parse;
import std.typecons : Flag, Yes, No;

ushort program_counter = 0;

ubyte[4] registers = [0, 0, 0, 0];

ubyte[] program_memory;

byte[255] memory;

ushort clock_delay = 0;

bool step_clock = false;

bool halt_on_error = true;

bool halt = false;

void main(string[] args)
{
	if (args.length == 1)
	{
		writeln(import("./help.txt"));
		return;
	}
	for (int i = 0; i < args.length; i++)
	{
		if (args[i] == "--help")
		{
			writeln(import("./help.txt"));
			return;
		}
		if (args[i] == "--bin")
		{
			program_memory = cast(ubyte[]) std.file.read(args[i + 1]);
			i++;
		}
		if (args[i] == "--slow")
		{
			auto a = parse!ushort(args[i + 1]);
			clock_delay = a;
			i++;
		}
		if (args[i] == "--step")
		{
			step_clock = true;
		}
		if (args[i] == "--ignore-error")
		{
			halt_on_error = false;
		}
	}

	writefln("loaded %s program bytes", program_memory.length);
	writefln("%s", program_memory);

	//Since the emulator loads 2 words at a time, must get 1 byte of padding
	program_memory ~= 0;

	while (!halt)
	{
		step();
		writefln("Registers: %s", registers);
		if (step_clock)
		{
			writeln("STEP MODE ENABLED - PRESS ENTER FOR NEXT CYCLE!");
			readln();

		}
		if (clock_delay > 0)
		{
			Thread.sleep(dur!"msecs"(clock_delay));
		}
	}

}

void step()
{
	//Load the 2 bytes and check if the instruction specified in the first byte uses 1 or 2 bytes
	ushort word = program_memory[program_counter] << 8 | program_memory[program_counter + 1];
	bool is_double_size = (word >> 15) == 1;
	byte immed = program_memory[program_counter + 1];
	//Increment the instruction register an appropriate amount
	program_counter++;
	if (is_double_size)
	{
		program_counter++;
	}

	ubyte opcode = word >> 12;
	ubyte Rd = ((word >> 10) & 0b00000011);
	ubyte Rs = ((word >> 8) & 0b00000011);
	writefln("--\nEXECUTED INSTRUCTION :\n WORD: %b \n OPCODE: %b \n RD: %b \n RS: %b", word, opcode, Rd, Rs);
	if (is_double_size)
	{
		writefln("IMMED: %b", immed);
	}
	writeln("--");
	switch (opcode)
	{
	case 0: //AND Rd,Rs - Rd = Rd AND Rs
		registers[Rd] = registers[Rd] & registers[Rs];
		break;
	case 1: //OR Rd,Rs - Rd = Rd OR Rs
		registers[Rd] = registers[Rd] | registers[Rs];
		break;
	case 2: //ADD Rd,Rs - Rd = Rd + Rs
		if (registers[Rd] > cast(ubyte)(registers[Rd] + registers[Rs]) && halt_on_error)
		{
			writeln("\x1B[33mAn integer overflow has occured. Press enter to continue.\x1B[0m");
			readln();
		}
		registers[Rd] = cast(ubyte)(registers[Rd] + registers[Rs]); //TODO: Add flags for overflow

		break;
	case 3: //SUB Rd,Rs - Rd = Rd - Rs
		if (registers[Rd] < cast(ubyte)(registers[Rd] - registers[Rs]) && halt_on_error)
		{
			writeln("\x1B[33mAn integer underflow has occured. Press enter to continue.\x1B[0m");
			readln();
		}
		registers[Rd] = cast(ubyte)(registers[Rd] - registers[Rs]); //TODO: Add flags for underflow
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
		if (registers[Rd] == 0)
		{
			program_counter = immed;
		}
		break;
	case 9: //JNE Rd,immed - if Rd != 0 -> PC = immed
		if (registers[Rd] != 0)
		{
			program_counter = immed;
		}
		break;
	case 10: //JGT Rd,immed - if Rd > 0 -> PC = immed
		if (registers[Rd] > 0)
		{
			program_counter = immed;
		}
		break;
	case 11: //JLT Rd,immed - if Rd < 0 -> PC = immed
		if (registers[Rd] < 0)
		{
			if (immed == program_counter - 2)
			{
				writefln("PC AT LOOPING PC: %s IMMED: %s - HALTING", program_counter, immed); //Just a basic halt if in a pointless loop
				halt = true;
			}
			program_counter = immed;
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
		if (immed == program_counter - 2)
		{
			writefln("PC AT LOOPING PC: %s IMMED: %s - HALTING", program_counter, immed); //Just a basic halt if in a pointless loop
			halt = true;
		}
		program_counter = immed;
		break;
	default:
		//Some bad shit happened!
		return;

	}

}