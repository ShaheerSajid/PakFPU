onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/fp_sqrt_inst/FP_FORMAT
add wave -noupdate /tb/fp_sqrt_inst/FP_WIDTH
add wave -noupdate /tb/fp_sqrt_inst/EXP_WIDTH
add wave -noupdate /tb/fp_sqrt_inst/MANT_WIDTH
add wave -noupdate /tb/fp_sqrt_inst/BIAS
add wave -noupdate /tb/fp_sqrt_inst/INF
add wave -noupdate /tb/fp_sqrt_inst/R_IND
add wave -noupdate /tb/fp_sqrt_inst/clk_i
add wave -noupdate /tb/fp_sqrt_inst/reset_i
add wave -noupdate /tb/fp_sqrt_inst/a_i
add wave -noupdate /tb/fp_sqrt_inst/start_i
add wave -noupdate /tb/fp_sqrt_inst/rnd_i
add wave -noupdate /tb/fp_sqrt_inst/done_o
add wave -noupdate /tb/fp_sqrt_inst/urnd_result_o
add wave -noupdate /tb/fp_sqrt_inst/result_o
add wave -noupdate /tb/fp_sqrt_inst/rs_o
add wave -noupdate /tb/fp_sqrt_inst/round_en_o
add wave -noupdate /tb/fp_sqrt_inst/invalid_o
add wave -noupdate /tb/fp_sqrt_inst/exp_cout_o
add wave -noupdate /tb/fp_sqrt_inst/urpr_s
add wave -noupdate /tb/fp_sqrt_inst/urpr_mant
add wave -noupdate /tb/fp_sqrt_inst/urpr_exp
add wave -noupdate /tb/fp_sqrt_inst/sign_o
add wave -noupdate /tb/fp_sqrt_inst/exp_o
add wave -noupdate /tb/fp_sqrt_inst/mant_o
add wave -noupdate /tb/fp_sqrt_inst/a_decoded
add wave -noupdate /tb/fp_sqrt_inst/a_info
add wave -noupdate -radix binary /tb/fp_sqrt_inst/mant_sqrt
add wave -noupdate -divider Sqrt
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/WIDTH
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/clk_i
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/reset_i
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/start_i
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/n_i
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/q_o
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/r_o
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/valid_o
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/R
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/Q
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/n
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/run_cnt
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/cur_state
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/nxt_state
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/lut
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/R_int
add wave -noupdate /tb/fp_sqrt_inst/int_sqrt_inst/R_fix
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {600 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 250
configure wave -valuecolwidth 243
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
WaveRestoreZoom {466 ps} {607 ps}
