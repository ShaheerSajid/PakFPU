onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /int_div/clk_i
add wave -noupdate /int_div/reset_i
add wave -noupdate /int_div/stall_i
add wave -noupdate /int_div/sign_i
add wave -noupdate /int_div/start_i
add wave -noupdate -radix decimal /int_div/n_i
add wave -noupdate -radix decimal /int_div/d_i
add wave -noupdate -radix decimal /int_div/q_o
add wave -noupdate -radix decimal /int_div/r_o
add wave -noupdate /int_div/valid_o
add wave -noupdate -divider {New Divider}
add wave -noupdate /int_div/cur_state
add wave -noupdate /int_div/nxt_state
add wave -noupdate -divider {New Divider}
add wave -noupdate -radix unsigned /int_div/R
add wave -noupdate -radix unsigned /int_div/D
add wave -noupdate -radix binary /int_div/Q
add wave -noupdate -radix unsigned /int_div/Q_fix
add wave -noupdate -divider {New Divider}
add wave -noupdate /int_div/n
add wave -noupdate /int_div/run_cnt
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1793 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 147
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
WaveRestoreZoom {1361 ns} {2409 ns}
