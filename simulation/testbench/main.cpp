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
#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

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
	uint32_t val = 0;
	val |= getNum(in[0]) << 4;
	val |= getNum(in[1]);
	return val;
}

uint64_t parse_hex_u64(const char *in)
{
	return strtoull(in, nullptr, 16);
}

void print_usage(const char *prog)
{
	fprintf(stderr, "Usage: %s <test_file> <roundmode> [num_inputs] [result_bits] [check_flags]\n", prog);
	fprintf(stderr, "  num_inputs : 1|2|3 (default: 2)\n");
	fprintf(stderr, "  result_bits: 1..64 (default: 32)\n");
	fprintf(stderr, "  check_flags: 0|1 (default: 1)\n");
}

vluint64_t sim_time = 0;
int main(int argc, char **argv)
{

	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(VM_TRACE);
	// Create an instance of our module under test
	Vtb *tb = new Vtb;
#if VM_TRACE
	VerilatedVcdC *m_trace = new VerilatedVcdC;
	// Tick the clock until we are done
	tb->trace(m_trace, 2);
	m_trace->open("waveform.vcd");
#endif

	FILE *fp;
	char *line = NULL;
	size_t len = 0;
	ssize_t read;

	if (argc < 3)
	{
		print_usage(argv[0]);
		exit(EXIT_FAILURE);
	}

	unsigned int rm = static_cast<unsigned int>(atoi(argv[2]));
	unsigned int num_inputs = (argc > 3) ? static_cast<unsigned int>(atoi(argv[3])) : 2;
	unsigned int result_bits = (argc > 4) ? static_cast<unsigned int>(atoi(argv[4])) : 32;
	unsigned int check_flags = (argc > 5) ? static_cast<unsigned int>(atoi(argv[5])) : 1;

	if (num_inputs < 1 || num_inputs > 3 || result_bits < 1 || result_bits > 64)
	{
		print_usage(argv[0]);
		exit(EXIT_FAILURE);
	}

	fp = fopen(argv[1], "r");
	if (fp == NULL)
		exit(EXIT_FAILURE);

	uint64_t a = 0, b = 0, c = 0, exp_res = 0, actual_res = 0;
	uint8_t exc;
	uint32_t test_cnt = 0;
	uint32_t err_cnt = 0;
	const uint64_t result_mask = (result_bits == 64) ? ~0ULL : ((1ULL << result_bits) - 1ULL);

	while ((read = getline(&line, &len, fp)) != -1)
	{

		char delim[] = " ";
		char *ptr = strtok(line, delim);
		int j = 0;
		char *vals[8];
		while (ptr != NULL)
		{
			vals[j] = ptr;
			ptr = strtok(NULL, delim);
			j++;
		}

		if (j == 0)
		{
			continue;
		}

		const int min_cols = static_cast<int>(num_inputs) + 2;
		if (j < min_cols)
		{
			fprintf(stderr, "Skipping malformed line (need %d cols, got %d)\n", min_cols, j);
			continue;
		}

		// calculate
		a = parse_hex_u64(vals[0]);
		b = (num_inputs >= 2) ? parse_hex_u64(vals[1]) : 0ULL;
		c = (num_inputs >= 3) ? parse_hex_u64(vals[2]) : 0ULL;
		exp_res = parse_hex_u64(vals[num_inputs]);
		exc = static_cast<uint8_t>(hex_to_int_8(vals[num_inputs + 1]));

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
#if VM_TRACE
			m_trace->dump(sim_time);
#endif
			sim_time++;
			tb->clk = 0;
			tb->eval();
#if VM_TRACE
			m_trace->dump(sim_time);
#endif
			sim_time++;
			tb->clk = 1;
			tb->eval();
			tb->start = 0;
#if VM_TRACE
			m_trace->dump(sim_time);
#endif
			sim_time++;

			while(!tb->valid) {
				tb->clk = 0;
				tb->eval();
#if VM_TRACE
				m_trace->dump(sim_time);
#endif
				sim_time++;
				tb->clk = 1;
				tb->eval();
#if VM_TRACE
				m_trace->dump(sim_time);
#endif
				sim_time++;
			}

			actual_res = tb->result;
			if (((exp_res & result_mask) != (actual_res & result_mask)) || (check_flags && tb->flags_o != exc))
			{
				// write errors to file!!!
				fprintf(stderr, "%016llx %016llx %016llx Expected=%016llx Actual=%016llx Ac.Flags=%d Exp.Flags=%d\n",
						(unsigned long long)a,
						(unsigned long long)b,
						(unsigned long long)c,
						(unsigned long long)exp_res,
						(unsigned long long)actual_res,
						tb->flags_o,
						exc);
				err_cnt++;
			}
		// }
	}
	fprintf(stdout, "Total Errors = %d/%d\t (%0.2f%%)\n", err_cnt, test_cnt, err_cnt * 100.0 / test_cnt);
	fclose(fp);
	if (line)
		free(line);
#if VM_TRACE
	m_trace->close();
#endif
	delete tb;
#if VM_TRACE
	delete m_trace;
#endif
	exit(EXIT_SUCCESS);
}
