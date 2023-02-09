#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace xsa_file"
	exit 0
}

set workspace [lindex $argv 0]
set xsa_file [lindex $argv 1]

setws $workspace

platform create -name {ultrascale_platform} -hw $xsa_file\
    -proc {psu_cortexa53_0} -os {standalone} -out $workspace

platform write

platform active {ultrascale_platform}
domain active {zynqmp_fsbl}
domain active {zynqmp_pmufw}

#platform write
platform generate
