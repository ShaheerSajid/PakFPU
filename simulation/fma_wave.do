onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/fp_add_inst/FP_FORMAT
add wave -noupdate -radix decimal /tb/fp_add_inst/FP_WIDTH
add wave -noupdate -radix decimal /tb/fp_add_inst/EXP_WIDTH
add wave -noupdate -radix decimal /tb/fp_add_inst/MANT_WIDTH
add wave -noupdate /tb/fp_add_inst/BIAS
add wave -noupdate /tb/fp_add_inst/INF
add wave -noupdate /tb/fp_add_inst/R_IND
add wave -noupdate -divider Inputs
add wave -noupdate -radix float32 /tb/fp_add_inst/a_i
add wave -noupdate -radix float32 /tb/fp_add_inst/b_i
add wave -noupdate -radix float32 /tb/fp_add_inst/c_i
add wave -noupdate /tb/fp_add_inst/sub_i
add wave -noupdate /tb/fp_add_inst/rnd_i
add wave -noupdate -divider Outputs
add wave -noupdate -expand /tb/fp_add_inst/rs_o
add wave -noupdate -subitemconfig {/tb/fp_add_inst/add_result.u_result -expand /tb/fp_add_inst/add_result.u_result.mant -expand} /tb/fp_add_inst/add_result
add wave -noupdate /tb/fp_add_inst/mant_o
add wave -noupdate /tb/fp_add_inst/urnd_result_o
add wave -noupdate -divider Decoded
add wave -noupdate /tb/fp_add_inst/a_decoded
add wave -noupdate /tb/fp_add_inst/b_decoded
add wave -noupdate /tb/fp_add_inst/c_decoded
add wave -noupdate /tb/fp_add_inst/a_info
add wave -noupdate /tb/fp_add_inst/b_info
add wave -noupdate /tb/fp_add_inst/c_info
add wave -noupdate -divider Mult
add wave -noupdate /tb/fp_add_inst/fp_mul_inst/a_i
add wave -noupdate /tb/fp_add_inst/fp_mul_inst/b_i
add wave -noupdate /tb/fp_add_inst/fp_mul_inst/urnd_result_o
add wave -noupdate /tb/fp_add_inst/mul_result
add wave -noupdate /tb/fp_add_inst/fp_mul_inst/norm_mant
add wave -noupdate /tb/fp_add_inst/uexp_o
add wave -noupdate /tb/fp_add_inst/umant_o
add wave -noupdate /tb/fp_add_inst/round_out
add wave -noupdate /tb/fp_add_inst/denorm_shift
add wave -noupdate /tb/fp_add_inst/stickyindex
add wave -noupdate /tb/fp_add_inst/sigB
add wave -noupdate /tb/fp_add_inst/compressed_mant
add wave -noupdate /tb/fp_add_inst/new_stickybit
add wave -noupdate /tb/fp_add_inst/joined_mul_result
add wave -noupdate {/tb/fp_add_inst/fp_add_inst/a_decoded.mant[24]}
add wave -noupdate {/tb/fp_add_inst/fp_add_inst/b_decoded.mant[24]}
add wave -noupdate {/tb/fp_add_inst/fp_add_inst/urnd_result_o.u_result.mant[24]}
add wave -noupdate -divider Adder
add wave -noupdate /tb/fp_add_inst/fp_add_inst/a_i
add wave -noupdate /tb/fp_add_inst/fp_add_inst/b_i
add wave -noupdate -subitemconfig {/tb/fp_add_inst/fp_add_inst/a_decoded.mant -expand} /tb/fp_add_inst/fp_add_inst/a_decoded
add wave -noupdate -subitemconfig {/tb/fp_add_inst/fp_add_inst/b_decoded.mant -expand} /tb/fp_add_inst/fp_add_inst/b_decoded
add wave -noupdate /tb/fp_add_inst/fp_add_inst/a_info
add wave -noupdate /tb/fp_add_inst/fp_add_inst/b_info
add wave -noupdate -subitemconfig {/tb/fp_add_inst/fp_add_inst/urnd_result_o.u_result -expand /tb/fp_add_inst/fp_add_inst/urnd_result_o.u_result.mant -expand} /tb/fp_add_inst/fp_add_inst/urnd_result_o
add wave -noupdate /tb/fp_add_inst/fp_add_inst/mant_o
add wave -noupdate /tb/fp_add_inst/fp_add_inst/exp_diff
add wave -noupdate /tb/fp_add_inst/fp_add_inst/shifted_mant
add wave -noupdate /tb/fp_add_inst/fp_add_inst/bigger_mant
add wave -noupdate /tb/fp_add_inst/fp_add_inst/urpr_s
add wave -noupdate /tb/fp_add_inst/fp_add_inst/urpr_exp
add wave -noupdate /tb/fp_add_inst/fp_add_inst/urpr_mant
add wave -noupdate /tb/fp_add_inst/fp_add_inst/shifted_mant_norm
add wave -noupdate /tb/fp_add_inst/fp_add_inst/bitout
add wave -noupdate /tb/fp_add_inst/fp_add_inst/sign_o
add wave -noupdate /tb/fp_add_inst/fp_add_inst/exp_o
add wave -noupdate -radix decimal /tb/fp_add_inst/fp_add_inst/stickyindex
add wave -noupdate /tb/fp_add_inst/fp_add_inst/sigB
add wave -noupdate /tb/fp_add_inst/fp_add_inst/compressed_mant
add wave -noupdate /tb/fp_add_inst/fp_add_inst/stickybit
add wave -noupdate -divider Round
add wave -noupdate -expand /tb/fp_rnd_inst/urnd_result_i
add wave -noupdate /tb/fp_rnd_inst/rnd_i
add wave -noupdate /tb/fp_rnd_inst/rnd_result_o
add wave -noupdate /tb/fp_rnd_inst/a_i
add wave -noupdate /tb/fp_rnd_inst/rs_i
add wave -noupdate /tb/fp_rnd_inst/round_en_i
add wave -noupdate /tb/fp_rnd_inst/invalid_i
add wave -noupdate /tb/fp_rnd_inst/exp_cout_i
add wave -noupdate /tb/fp_rnd_inst/out_o
add wave -noupdate /tb/fp_rnd_inst/flags_o
add wave -noupdate /tb/fp_rnd_inst/round_bit
add wave -noupdate /tb/fp_rnd_inst/sticky_bit
add wave -noupdate /tb/fp_rnd_inst/uround_bit
add wave -noupdate /tb/fp_rnd_inst/usticky_bit
add wave -noupdate /tb/fp_rnd_inst/round_out
add wave -noupdate /tb/fp_rnd_inst/round_up
add wave -noupdate /tb/fp_rnd_inst/rounded_mant
add wave -noupdate /tb/fp_rnd_inst/uround_up
add wave -noupdate /tb/fp_rnd_inst/urounded_mant
add wave -noupdate /tb/fp_rnd_inst/sign_o
add wave -noupdate /tb/fp_rnd_inst/exp_o
add wave -noupdate /tb/fp_rnd_inst/mant_o
add wave -noupdate /tb/fp_rnd_inst/usign_o
add wave -noupdate /tb/fp_rnd_inst/uexp_o
add wave -noupdate /tb/fp_rnd_inst/umant_o
add wave -noupdate /tb/fp_rnd_inst/ovf
add wave -noupdate /tb/fp_rnd_inst/uf
add wave -noupdate /tb/fp_rnd_inst/denorm_shift
add wave -noupdate /tb/fp_rnd_inst/stickyindex
add wave -noupdate /tb/fp_rnd_inst/sigB
add wave -noupdate /tb/fp_rnd_inst/compressed_mant
add wave -noupdate /tb/fp_rnd_inst/new_stickybit
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {90 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 281
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
WaveRestoreZoom {0 ps} {725 ps}
