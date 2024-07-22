#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h> // for strtol
#include <sstream>
#include <iostream>
#include "Vtb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

uint8_t getNum(char ch)
{
	uint8_t num = 0;
	if (ch >= '0' && ch <= '9')
	{
		num = ch - 0x30;
	}
	else
	{
		switch (ch)
		{
		case 'A':
		case 'a':
			num = 10;
			break;
		case 'B':
		case 'b':
			num = 11;
			break;
		case 'C':
		case 'c':
			num = 12;
			break;
		case 'D':
		case 'd':
			num = 13;
			break;
		case 'E':
		case 'e':
			num = 14;
			break;
		case 'F':
		case 'f':
			num = 15;
			break;
		default:
			num = 0;
		}
	}
	return num;
}
uint32_t hex_to_int_32(char *in)
{
	uint32_t val = 0;
	val |= getNum(in[0]) << 28;
	val |= getNum(in[1]) << 24;
	val |= getNum(in[2]) << 20;
	val |= getNum(in[3]) << 16;
	val |= getNum(in[4]) << 12;
	val |= getNum(in[5]) << 8;
	val |= getNum(in[6]) << 4;
	val |= getNum(in[7]);

	return val;
}

uint64_t hex_to_int_64(char *in)
{
	uint64_t val = 0;
	val |= (uint64_t)getNum(in[0]) << 60;
	val |= (uint64_t)getNum(in[1]) << 56;
	val |= (uint64_t)getNum(in[2]) << 52;
	val |= (uint64_t)getNum(in[3]) << 48;
	val |= (uint64_t)getNum(in[4]) << 44;
	val |= (uint64_t)getNum(in[5]) << 40;
	val |= (uint64_t)getNum(in[6]) << 36;
	val |= (uint64_t)getNum(in[7]) << 32;
	val |= (uint64_t)getNum(in[8]) << 28;
	val |= (uint64_t)getNum(in[9]) << 24;
	val |= (uint64_t)getNum(in[10]) << 20;
	val |= (uint64_t)getNum(in[11]) << 16;
	val |= (uint64_t)getNum(in[12]) << 12;
	val |= (uint64_t)getNum(in[13]) << 8;
	val |= (uint64_t)getNum(in[14]) << 4;
	val |= (uint64_t)getNum(in[15]);

	return val;
}
uint32_t hex_to_int_8(char *in)
{
	uint32_t val;
	val |= getNum(in[0]) << 4;
	val |= getNum(in[1]);
	return val;
}

vluint64_t sim_time = 0;
int main(int argc, char **argv)
{

	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	// Create an instance of our module under test
	Vtb *tb = new Vtb;
	VerilatedVcdC *m_trace = new VerilatedVcdC;
	// Tick the clock until we are done
	tb->trace(m_trace, 2);
	m_trace->open("waveform.vcd");

	FILE *fp;
	char *line = NULL;
	size_t len = 0;
	ssize_t read;

	unsigned int rm = atoi(argv[2]);

	fp = fopen(argv[1], "r");
	if (fp == NULL)
		exit(EXIT_FAILURE);

	uint64_t a, b, c, exp_res, actual_res;
	uint8_t exc;
	uint32_t test_cnt = 0;
	uint32_t err_cnt = 0;

	while ((read = getline(&line, &len, fp)) != -1)
	{

		int init_size = strlen(line);
		char delim[] = " ";
		char *ptr = strtok(line, delim);
		int j = 0;
		char *vals[5];
		while (ptr != NULL)
		{
			vals[j] = ptr;
			ptr = strtok(NULL, delim);
			j++;
		}
		// calculate
		a = hex_to_int_32(vals[0]);

		// exp_res = hex_to_int_64(vals[1]);
		// exc = hex_to_int_8(vals[2]);

		// b = hex_to_int_32(vals[1]);
		// c = hex_to_int_32(vals[2]);
		exp_res = hex_to_int_32(vals[1]);
		exc = hex_to_int_8(vals[2]);

		// if (((a & 0x7F800000) == 0x00000000))
		// {
			test_cnt++;
			tb->opA = a;
			tb->opB = b;
			tb->opC = c;
			tb->rnd = rm;

			tb->rst = 1;
			tb->clk = 1;
			tb->start = 1;
			tb->eval();
			m_trace->dump(sim_time);
			sim_time++;
			tb->clk = 0;
			tb->eval();
			m_trace->dump(sim_time);
			sim_time++;
			tb->clk = 1;
			tb->eval();
			tb->start = 0;
			m_trace->dump(sim_time);
			sim_time++;

			while(!tb->valid) {
				tb->clk = 0;
				tb->eval();
				m_trace->dump(sim_time);
				sim_time++;
				tb->clk = 1;
				tb->eval();
				m_trace->dump(sim_time);
				sim_time++;
			}

			actual_res = tb->result;
			if (exp_res != actual_res || tb->flags_o != exc)
			{
				// write errors to file!!!
				fprintf(stderr, "%016lx %016lx %016lx Expected=%016lx Actual=%016lx Ac.Flags=%d Exp.Flags=%d\n", a, b, c, exp_res, actual_res, tb->flags_o, exc);
				err_cnt++;
			}
		// }
	}
	fprintf(stdout, "Total Errors = %d/%d\t (%0.2f%%)\n", err_cnt, test_cnt, err_cnt * 100.0 / test_cnt);
	fclose(fp);
	if (line)
		free(line);
	m_trace->close();
	delete tb;
	delete m_trace;
	exit(EXIT_SUCCESS);
}