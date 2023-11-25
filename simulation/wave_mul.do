onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/fp32_mul_inst/a_i
add wave -noupdate /tb/fp32_mul_inst/b_i
add wave -noupdate /tb/fp32_mul_inst/result_o
add wave -noupdate /tb/fp32_mul_inst/rs_o
add wave -noupdate /tb/fp32_mul_inst/round_en_o
add wave -noupdate /tb/fp32_mul_inst/invalid_o
add wave -noupdate /tb/fp32_mul_inst/exp_cout_o
add wave -noupdate /tb/fp32_mul_inst/urpr_s
add wave -noupdate /tb/fp32_mul_inst/urpr_mant
add wave -noupdate /tb/fp32_mul_inst/urpr_exp
add wave -noupdate /tb/fp32_mul_inst/sign_o
add wave -noupdate /tb/fp32_mul_inst/exp_o
add wave -noupdate /tb/fp32_mul_inst/mant_o
add wave -noupdate -childformat {{/tb/fp32_mul_inst/a_decoded.exp -radix unsigned}} -expand -subitemconfig {/tb/fp32_mul_inst/a_decoded.exp {-radix unsigned}} /tb/fp32_mul_inst/a_decoded
add wave -noupdate -expand /tb/fp32_mul_inst/b_decoded
add wave -noupdate /tb/fp32_mul_inst/a_info
add wave -noupdate /tb/fp32_mul_inst/b_info
add wave -noupdate -divider {New Divider}
add wave -noupdate -childformat {{/tb/fp_rnd_inst/a_i.exp -radix decimal}} -expand -subitemconfig {/tb/fp_rnd_inst/a_i.exp {-radix decimal}} /tb/fp_rnd_inst/a_i
add wave -noupdate /tb/fp_rnd_inst/rnd_i
add wave -noupdate /tb/fp_rnd_inst/rs_i
add wave -noupdate /tb/fp_rnd_inst/round_en_i
add wave -noupdate /tb/fp_rnd_inst/out_o
add wave -noupdate /tb/fp_rnd_inst/invalid_i
add wave -noupdate /tb/fp_rnd_inst/exp_cout_i
add wave -noupdate /tb/fp_rnd_inst/flags_o
add wave -noupdate /tb/fp_rnd_inst/round_bit
add wave -noupdate /tb/fp_rnd_inst/sticky_bit
add wave -noupdate /tb/fp_rnd_inst/round_up
add wave -noupdate /tb/fp_rnd_inst/rounded_mant
add wave -noupdate /tb/fp_rnd_inst/sign_o
add wave -noupdate /tb/fp_rnd_inst/exp_o
add wave -noupdate /tb/fp_rnd_inst/mant_o
add wave -noupdate /tb/fp_rnd_inst/usign_o
add wave -noupdate /tb/fp_rnd_inst/uexp_o
add wave -noupdate /tb/fp_rnd_inst/umant_o
add wave -noupdate /tb/fp_rnd_inst/ovf
add wave -noupdate /tb/fp_rnd_inst/uf
add wave -noupdate /tb/fp_rnd_inst/denorm_shift
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {366 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 212
configure wave -valuecolwidth 148
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
WaveRestoreZoom {353 ps} {448 ps}
