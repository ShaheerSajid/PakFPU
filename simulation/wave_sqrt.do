onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /int_sqrt/WIDTH
add wave -noupdate /int_sqrt/clk_i
add wave -noupdate /int_sqrt/reset_i
add wave -noupdate /int_sqrt/start_i
add wave -noupdate /int_sqrt/n_i
add wave -noupdate -radix unsigned /int_sqrt/q_o
add wave -noupdate /int_sqrt/r_o
add wave -noupdate /int_sqrt/valid_o
add wave -noupdate -radix binary /int_sqrt/R
add wave -noupdate -radix binary /int_sqrt/Q
add wave -noupdate /int_sqrt/n
add wave -noupdate -radix unsigned /int_sqrt/run_cnt
add wave -noupdate /int_sqrt/cur_state
add wave -noupdate /int_sqrt/nxt_state
add wave -noupdate /int_sqrt/lut
add wave -noupdate -radix binary /int_sqrt/R_int
add wave -noupdate /int_sqrt/R_fix
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1100 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 174
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
WaveRestoreZoom {447 ns} {1598 ns}
