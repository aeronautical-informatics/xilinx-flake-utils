#!/usr/bin/env xsct

if { $argc != 6 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name bit_file xsa_file pmufw_file fsbl_file zynqmp_utils elf_file"
	exit 0
}

set bit_file [lindex $argv 0]
set xsa_file [lindex $argv 1]
set pmufw_file [lindex $argv 2]
set fsbl_file [lindex $argv 3]
set zynqmp_utils [lindex $argv 4]
set elf_file [lindex $argv 5]

source $zynqmp_utils

connect -url tcp:127.0.0.1:3121

set jtag_id [dict get [lindex [ jtag targets -filter {level == 0} -target-properties] 0] name]

if { ($jtag_id == "JTAG-ONB4 2516330067ABA") || ($jtag_id == "JTAG-ONB4 2516330067ACA") } {
	puts "Set bootmode to JTAG"
	targets -set -nocase -filter {name =~ "*PSU*"}
	stop
	mwr 0xff5e0200 0x0100
	rst -system
}

targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
#targets -set -filter {jtag_cable_name =~ "JTAG-ONB4 2516330067ACA" && level==0} -index 0
#targets -set -filter {jtag_cable_name =~ "JTAG-ONB4 2516330594A9A" && level==0} -index 0
fpga -file $bit_file
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw $xsa_file -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}]

#Disable Security gates to view PMU MB target
targets -set -filter {name =~ "PSU"}
mwr 0xffca0038 0x1ff
after 500
  
#Load and run PMU FW
targets -set -filter {name =~ "MicroBlaze PMU"}
dow $pmufw_file
con
after 500

configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}
set mode [expr [mrd -value 0xFF5E0200] & 0xf]

targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow $fsbl_file
set bp_24_56_fsbl_bp [bpadd -addr &XFsbl_Exit]
con -block -timeout 60
bpremove $bp_24_56_fsbl_bp
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor

dow $elf_file

configparams force-mem-access 0

targets -set -nocase -filter {name =~ "*A53*#0"}
con
