#!/usr/bin/env xsct

if { $argc != 4 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name ps7_init_file bit_file xsa_file elf_file"
	exit 0
}

set ps7_init_file [lindex $argv 0]
set bit_file [lindex $argv 1]
set xsa_file [lindex $argv 2]
set elf_file [lindex $argv 3]

# ps7_init.tcl
source $ps7_init_file

connect

# This file is executed by the XSCT/ XSDB to configure the platform during boot process
# It gets the .elf file for the specific application handed over

set jtag_id [dict get [lindex [ jtag targets -filter {level == 0} -target-properties] 0] name]

if { ($jtag_id == "JTAG-ONB4 2516330067ABA") || ($jtag_id == "JTAG-ONB4 2516330067ACA") } {
	puts "Set bootmode to JTAG"
	targets -set -nocase -filter {name =~ "*PSU*"}
	stop
	mwr 0xff5e0200 0x0100
	rst -system
}

targets -set -nocase -filter {name =~ "APU*"};
rst -system

# wait until reset on hardware is done
after 500

# download fpga bitstream file
fpga -file $bit_file
targets -set -nocase -filter {name =~ "APU*"};

# download hw xsa file
loadhw -hw $xsa_file -mem-ranges [list {0x40000000 0xbfffffff}]

configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}

ps7_init
ps7_post_config

targets -set -nocase -filter {name =~ "*A9*#0"}

# download application elf
dow $elf_file

configparams force-mem-access 0

targets -set -nocase -filter {name =~ "*A9*#0"}

rwr r0 0x00200000

con
