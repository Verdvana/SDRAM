transcript on
if ![file isdirectory SDRAM_iputf_libs] {
	file mkdir SDRAM_iputf_libs
}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

###### Libraries for IPUTF cores 
###### End libraries for IPUTF cores 
###### MIF file copy and HDL compilation commands for IPUTF cores 


vlog "E:/DE1-SoC/FPGA/SDRAM/Sdram_PLL_sim/Sdram_PLL.vo"
vlog "E:/DE1-SoC/FPGA/SDRAM/PLL_sim/PLL.vo"            

vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/SDRAM.v}
vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/Sdram_RD_FIFO.v}
vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/Sdram_WR_FIFO.v}
vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/segment.v}
vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/control_interface.v}
vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/sdram_control.v}
vlog -vlog01compat -work work +incdir+E:/DE1-SoC/FPGA/SDRAM {E:/DE1-SoC/FPGA/SDRAM/command.v}
vlib PLL
vmap PLL PLL
vlog -vlog01compat -work PLL +incdir+E:/DE1-SoC/FPGA/SDRAM/PLL {E:/DE1-SoC/FPGA/SDRAM/PLL/PLL_0002.v}

