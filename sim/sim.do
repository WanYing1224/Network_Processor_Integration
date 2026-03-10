# SW_Simulation.do

add wave -noupdate -divider "Network FIFO Interface"
add wave -noupdate /system_integration_tb/dut/ARM_Core/fifo_mode_en
add wave -noupdate /system_integration_tb/dut/ARM_Core/packet_ready
add wave -noupdate -radix hex /system_integration_tb/dut/ARM_Core/fifo_data_in
add wave -noupdate /system_integration_tb/dut/ARM_Core/fifo_wr_en
add wave -noupdate -radix hex /system_integration_tb/dut/ARM_Core/fifo_data_out

add wave -noupdate -divider "Co-Processor Handshake"
add wave -noupdate /system_integration_tb/dut/Arbiter/gpu_run
add wave -noupdate /system_integration_tb/dut/Arbiter/stall_arm_pipeline
add wave -noupdate /system_integration_tb/dut/Arbiter/precedence

add wave -noupdate -divider "Tensor GPU Core"
add wave -noupdate -radix hex /system_integration_tb/dut/GPU_Core/pc_inst/pc
add wave -noupdate -radix hex /system_integration_tb/dut/GPU_Core/tensor_inst/acc_out

add wave -noupdate -divider "ARM Core"
add wave -position end  sim:/system_integration_tb/dut/ARM_Core/hw_pc
add wave -position end  sim:/system_integration_tb/dut/ARM_Core/thread_id_reg
add wave -position end  sim:/system_integration_tb/dut/ARM_Core/actual_stall

run -all

# HW_Simulation.d0
add wave -noupdate -divider "PCIe Bootloader Bus"
add wave -noupdate -radix hex /hw_integration_tb/dut/ARM_Core/sw_mem_addr
add wave -noupdate -radix hex /hw_integration_tb/dut/ARM_Core/sw_mem_wdata
add wave -noupdate /hw_integration_tb/dut/ARM_Core/sw_mem_cmd

add wave -noupdate -divider "Physical Memory Arrays"
add wave -position 5  sim:/hw_integration_tb/dut/ARM_Core/IMEM/imem[0]
add wave -noupdate -radix hex {/hw_integration_tb/dut/ARM_Core/DMem/dmem[0]}
add wave -position end  sim:/hw_integration_tb/dut/GPU_Core/pc_inst_mem/ram[0]

run 60000ns