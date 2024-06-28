onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/clk
add wave -noupdate /tb/rst
add wave -noupdate /tb/start
add wave -noupdate /tb/valid
add wave -noupdate -radix float32 /tb/opA
add wave -noupdate -radix float32 /tb/opB
add wave -noupdate -radix float32 /tb/exp_res
add wave -noupdate -radix float32 /tb/result
add wave -noupdate /tb/err_cnt
add wave -noupdate -divider {New Divider}
add wave -noupdate /tb/fp_div_inst/a_i
add wave -noupdate /tb/fp_div_inst/b_i
add wave -noupdate /tb/fp_div_inst/start_i
add wave -noupdate /tb/fp_div_inst/urpr_s
add wave -noupdate /tb/fp_div_inst/urpr_mant
add wave -noupdate /tb/fp_div_inst/urpr_exp
add wave -noupdate /tb/fp_div_inst/sign_o
add wave -noupdate /tb/fp_div_inst/exp_o
add wave -noupdate /tb/fp_div_inst/mant_o
add wave -noupdate -expand /tb/fp_div_inst/a_decoded
add wave -noupdate -expand /tb/fp_div_inst/b_decoded
add wave -noupdate /tb/fp_div_inst/a_info
add wave -noupdate /tb/fp_div_inst/b_info
add wave -noupdate /tb/fp_div_inst/shifted_mant_norm
add wave -noupdate /tb/fp_div_inst/shamt
add wave -noupdate -divider {INT DIV}
add wave -noupdate /tb/fp_div_inst/int_div_inst/clk_i
add wave -noupdate /tb/fp_div_inst/int_div_inst/reset_i
add wave -noupdate /tb/fp_div_inst/int_div_inst/start_i
add wave -noupdate /tb/fp_div_inst/int_div_inst/n_i
add wave -noupdate /tb/fp_div_inst/int_div_inst/d_i
add wave -noupdate /tb/fp_div_inst/int_div_inst/q_o
add wave -noupdate /tb/fp_div_inst/int_div_inst/valid_o
add wave -noupdate /tb/fp_div_inst/int_div_inst/R
add wave -noupdate /tb/fp_div_inst/int_div_inst/D
add wave -noupdate /tb/fp_div_inst/int_div_inst/Q
add wave -noupdate /tb/fp_div_inst/int_div_inst/n
add wave -noupdate /tb/fp_div_inst/int_div_inst/run_cnt
add wave -noupdate /tb/fp_div_inst/int_div_inst/n_internal
add wave -noupdate /tb/fp_div_inst/int_div_inst/d_internal
add wave -noupdate /tb/fp_div_inst/int_div_inst/cur_state
add wave -noupdate /tb/fp_div_inst/int_div_inst/nxt_state
add wave -noupdate /tb/fp_div_inst/int_div_inst/Q_fix
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {44484819 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 237
configure wave -valuecolwidth 151
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
WaveRestoreZoom {39473049 ps} {153032429 ps}
