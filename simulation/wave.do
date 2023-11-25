onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb/opA
add wave -noupdate -radix hexadecimal /tb/opB
add wave -noupdate -radix hexadecimal /tb/u_result
add wave -noupdate -radix hexadecimal /tb/result
add wave -noupdate -divider {New Divider}
add wave -noupdate /tb/fp_add_inst/exp_diff
add wave -noupdate /tb/fp_add_inst/shifted_mant
add wave -noupdate /tb/fp_add_inst/bigger_mant
add wave -noupdate /tb/fp_add_inst/urpr_s
add wave -noupdate /tb/fp_add_inst/urpr_mant
add wave -noupdate /tb/fp_add_inst/urpr_exp
add wave -noupdate /tb/fp_add_inst/sign_o
add wave -noupdate /tb/fp_add_inst/exp_o
add wave -noupdate /tb/fp_add_inst/mant_o
add wave -noupdate -expand /tb/fp_add_inst/a_decoded
add wave -noupdate -expand /tb/fp_add_inst/b_decoded
add wave -noupdate /tb/fp_add_inst/a_info
add wave -noupdate /tb/fp_add_inst/b_info
add wave -noupdate /tb/fp_add_inst/shifted_mant_norm
add wave -noupdate /tb/fp_add_inst/shamt
add wave -noupdate /tb/fp_add_inst/stickyindex
add wave -noupdate -expand /tb/fp_add_inst/sig
add wave -noupdate /tb/fp_add_inst/sigB
add wave -noupdate /tb/fp_add_inst/compressed_mant
add wave -noupdate /tb/fp_add_inst/stickybit
add wave -noupdate -divider {New Divider}
add wave -noupdate /tb/fp_rnd_inst/a_i
add wave -noupdate /tb/fp_rnd_inst/rnd_i
add wave -noupdate /tb/fp_rnd_inst/rs_i
add wave -noupdate /tb/fp_rnd_inst/round_en_i
add wave -noupdate /tb/fp_rnd_inst/out_o
add wave -noupdate /tb/fp_rnd_inst/round_up_bit
add wave -noupdate /tb/fp_rnd_inst/round_bit
add wave -noupdate /tb/fp_rnd_inst/sticky_bit
add wave -noupdate /tb/fp_rnd_inst/round_up
add wave -noupdate /tb/fp_rnd_inst/rounded_mant
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {11348 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 235
configure wave -valuecolwidth 100
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
WaveRestoreZoom {11165 ps} {11373 ps}
