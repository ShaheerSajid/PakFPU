TEST = $(TEST)
LEVEL = $(LEVEL)

gen_test: 
	echo "Generating Tests"
	echo "${TEST} RDN"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rmin -seed 1000 -n 10000000 -level $(LEVEL) > testbench/test_rdn.txt 
	echo "${TEST} RUP"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rmax -seed 1000 -n 10000000 -level $(LEVEL) > testbench/test_rup.txt
	echo "${TEST} RTZ"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rminMag -seed 1000 -n 10000000 -level $(LEVEL) > testbench/test_rtz.txt
	echo "${TEST} RNE"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rnear_even -seed 1000 -n 10000000 -level $(LEVEL) > testbench/test_rne.txt
	echo "${TEST} RMM"
	./testfloat/testfloat_gen ${TEST} -tininessafter -rnear_maxMag -seed 1000 -n 10000000 -level $(LEVEL) > testbench/test_rmm.txt
	echo $(date) > gen_test

questa_sim:
	if [ -d "work" ]; then  vdel -lib work -all; fi
	vlib work
	vlog -sv -work work -f src.args
	vlog -sv -work work +incdir+/home/shaheer/Documents/projects/PakFPU/src testbench/tb.sv
	vsim -t 1ps -L work -voptargs="+acc" tb -do "do wave.do; run -all; exit"
	
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
	+incdir+/home/shaheer/Documents/projects/PakFPU/src \
	-f src.args \
	testbench/tb.sv \
	--exe testbench/main.cpp
	make -s -j -C obj_dir/ -f Vtb.mk Vtb
	echo "Running Testbench"
	echo -n "${TEST} RTZ: "
	echo "${TEST} RTZ Errors" >> err.txt
	obj_dir/Vtb	testbench/test_rtz.txt 1 2>> err.txt
	
	
.PHONY: questa
questa: gen_test questa_sim

.PHONY: verilator
verilator: gen_test verilator_sim

.PHONY: clean
clean: 
	rm -rf testbench/*.txt
	rm -rf work
	rm -rf transcript *.wlf
	rm -rf *.txt
	rm -rf obj_dir
	rm -rf *.vcd
	rm -rf gen_test
