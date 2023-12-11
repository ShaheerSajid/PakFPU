onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/fp_add_inst/FP_FORMAT
add wave -noupdate /tb/fp_add_inst/FP_WIDTH
add wave -noupdate /tb/fp_add_inst/EXP_WIDTH
add wave -noupdate /tb/fp_add_inst/MANT_WIDTH
add wave -noupdate /tb/fp_add_inst/BIAS
add wave -noupdate /tb/fp_add_inst/INF
add wave -noupdate /tb/fp_add_inst/R_IND
add wave -noupdate /tb/fp_add_inst/a_i
add wave -noupdate /tb/fp_add_inst/b_i
add wave -noupdate /tb/fp_add_inst/c_i
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
add wave -noupdate /tb/fp_add_inst/exp_eq
add wave -noupdate /tb/fp_add_inst/exp_lt
add wave -noupdate /tb/fp_add_inst/mant_eq
add wave -noupdate /tb/fp_add_inst/mant_lt
add wave -noupdate /tb/fp_add_inst/lt
add wave -noupdate /tb/fp_add_inst/exp_diff
add wave -noupdate /tb/fp_add_inst/shifted_mant
add wave -noupdate /tb/fp_add_inst/bigger_mant
add wave -noupdate /tb/fp_add_inst/urpr_s
add wave -noupdate -radix binary /tb/fp_add_inst/urpr_mant
add wave -noupdate -radix binary /tb/fp_add_inst/shifted_mant_norm
add wave -noupdate -radix binary /tb/fp_add_inst/mant_o
add wave -noupdate /tb/fp_add_inst/urpr_exp
add wave -noupdate /tb/fp_add_inst/sign_o
add wave -noupdate /tb/fp_add_inst/exp_o
add wave -noupdate /tb/fp_add_inst/stickyindex
add wave -noupdate /tb/fp_add_inst/sigB
add wave -noupdate /tb/fp_add_inst/compressed_mant
add wave -noupdate /tb/fp_add_inst/stickybit
add wave -noupdate /tb/fp_add_inst/shamt
add wave -noupdate /tb/fp_add_inst/bitout
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
