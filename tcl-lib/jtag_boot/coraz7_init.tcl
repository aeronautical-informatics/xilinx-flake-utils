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

source $ps7_init_file

# connect to target
connect -url tcp:127.0.0.1:3121

targets -set -nocase -filter {name =~ "APU*"};
rst -system

# wait until reset on hardware is done
after 500

# download fpga file
fpga -file $bit_file
targets -set -nocase -filter {name =~ "APU*"};
loadhw -hw $xsa_file -mem-ranges [list {0x40000000 0xbfffffff}]

configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}

ps7_init
ps7_post_config

targets -set -nocase -filter {name =~ "*A9*#0"}

dow $elf_file

configparams force-mem-access 0

targets -set -nocase -filter {name =~ "*A9*#0"}

rwr r0 0x00200000 

con
