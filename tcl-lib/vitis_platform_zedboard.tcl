#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace xsa_file"
	exit 0
}

set workspace [lindex $argv 0]
set xsa_file [lindex $argv 1]

setws $workspace

platform create -name {zedboard_platform} -hw $xsa_file\
    -proc {ps7_cortexa9_0} -os {standalone} -out $workspace

platform write

platform active {zedboard_platform}
domain active {zynq_fsbl}
domain active {standalone_domain}

bsp setlib -name xilffs
bsp regenerate

platform write
platform generate

# fsbl standard
app create -name fsbl_standard_zedboard -platform zedboard_platform -domain standalone_domain -template {Zynq FSBL}
app config -name fsbl_standard_zedboard build-config Release
app build fsbl_standard_zedboard

# fsbl modified (used to load sw in flash)
#app create -name fsbl_modified_zedboard -platform zedboard_platform -domain standalone_domain -template {Zynq FSBL}
#app config -name fsbl_modified_zedboard build-config Release
