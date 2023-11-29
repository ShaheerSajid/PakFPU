TEST = $(TEST)
LEVEL = $(LEVEL)

gen_test: 
	echo "Generating Tests"
	echo "${TEST} RDN"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rmin -seed 1000 -level $(LEVEL) > testbench/test_rdn.txt 
	echo "${TEST} RUP"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rmax -seed 1000 -level $(LEVEL) > testbench/test_rup.txt
	echo "${TEST} RTZ"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rminMag -seed 1000 -level $(LEVEL) > testbench/test_rtz.txt
	echo "${TEST} RNE"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rnear_even -seed 1000 -level $(LEVEL) > testbench/test_rne.txt
	echo "${TEST} RMM"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rnear_maxMag -seed 1000 -level $(LEVEL) > testbench/test_rmm.txt

questa_sim:
	if [ -d "work" ]; then  vdel -lib work -all; fi
	vlib work
	vlog -sv -work work -f src.args
	vlog -sv -work work testbench/tb.sv
	clear
	vsim -c -t 1ps -L work -voptargs="+acc" tb -do "run -all; exit"
	
verilator_sim:
	echo "Compiling Testbench"
	verilator \
	-Wno-WIDTH \
	-Wno-PINMISSING \
	-O3 \
	--trace \
	--timescale-override 1ns/10ps \
	-sv --top-module tb \
	--cc \
	-f src.args \
	testbench/tb.sv \
	--exe testbench/main.cpp
	make -s -j -C obj_dir/ -f Vtb.mk Vtb
	echo "Running Testbench"
	echo -n "${TEST} RDN: "
	echo "${TEST} RDN Errors" >  err.txt
	obj_dir/Vtb	testbench/test_rdn.txt 2 2>> err.txt
	echo -n "${TEST} RUP: "
	echo "${TEST} RUP Errors" >> err.txt
	obj_dir/Vtb	testbench/test_rup.txt 3 2>> err.txt
	echo -n "${TEST} RTZ: "
	echo "${TEST} RTZ Errors" >> err.txt
	obj_dir/Vtb	testbench/test_rtz.txt 1 2>> err.txt
	echo -n "${TEST} RNE: "
	echo "${TEST} RNE Errors" >> err.txt
	obj_dir/Vtb	testbench/test_rne.txt 0 2>> err.txt
	echo -n "${TEST} RMM: "
	echo "${TEST} RMM Errors" >> err.txt
	obj_dir/Vtb	testbench/test_rmm.txt 4 2>> err.txt
	gtkwave --dump waveform.vcd
	
	
.PHONY: questa
questa: gen_test questa_sim

.PHONY: verilator
verilator: gen_test verilator_sim
