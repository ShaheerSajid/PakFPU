onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/fp_add_inst/FP_FORMAT
add wave -noupdate /tb/fp_add_inst/FP_WIDTH
add wave -noupdate /tb/fp_add_inst/EXP_WIDTH
add wave -noupdate /tb/fp_add_inst/MANT_WIDTH
add wave -noupdate /tb/fp_add_inst/BIAS
add wave -noupdate /tb/fp_add_inst/INF
add wave -noupdate /tb/fp_add_inst/R_IND
add wave -noupdate -radix float32 /tb/fp_add_inst/a_i
add wave -noupdate -radix float32 /tb/fp_add_inst/b_i
add wave -noupdate -radix float32 /tb/fp_add_inst/c_i
add wave -noupdate /tb/fp_add_inst/start_i
add wave -noupdate /tb/fp_add_inst/sub_i
add wave -noupdate /tb/fp_add_inst/rnd_i
add wave -noupdate /tb/fp_add_inst/done_o
add wave -noupdate /tb/fp_add_inst/urnd_result_o
add wave -noupdate /tb/fp_add_inst/result_o
add wave -noupdate /tb/fp_add_inst/rs_o
add wave -noupdate /tb/fp_add_inst/round_en_o
add wave -noupdate /tb/fp_add_inst/invalid_o
add wave -noupdate /tb/fp_add_inst/exp_cout_o
add wave -noupdate /tb/fp_add_inst/a_decoded
add wave -noupdate /tb/fp_add_inst/b_decoded
add wave -noupdate /tb/fp_add_inst/c_decoded
add wave -noupdate /tb/fp_add_inst/a_info
add wave -noupdate /tb/fp_add_inst/b_info
add wave -noupdate /tb/fp_add_inst/c_info
add wave -noupdate /tb/fp_add_inst/mul_urpr_s
add wave -noupdate /tb/fp_add_inst/mul_urpr_mant
add wave -noupdate /tb/fp_add_inst/mul_urpr_exp
add wave -noupdate /tb/fp_add_inst/mul_invalid
add wave -noupdate -radix unsigned /tb/fp_add_inst/shamt
add wave -noupdate /tb/fp_add_inst/add_urpr_s
add wave -noupdate /tb/fp_add_inst/add_shift_mant
add wave -noupdate /tb/fp_add_inst/add_urpr_mant
add wave -noupdate /tb/fp_add_inst/add_urpr_exp
add wave -noupdate /tb/fp_add_inst/stickyindex
add wave -noupdate /tb/fp_add_inst/sigC
add wave -noupdate /tb/fp_add_inst/compressed_mant
add wave -noupdate /tb/fp_add_inst/stickybit
add wave -noupdate /tb/result
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {50 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 222
configure wave -valuecolwidth 244
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {24 ps} {76 ps}
