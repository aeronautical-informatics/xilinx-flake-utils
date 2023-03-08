#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace xsa_file"
	exit 0
}

set workspace [lindex $argv 0]
set xsa_file [lindex $argv 1]

setws $workspace

platform create -name {ultrascale_platform} -hw $xsa_file \
	-proc {psu_cortexa53_0} -os {standalone} -out $workspace

platform write

platform active {ultrascale_platform}

domain active {zynqmp_fsbl}
bsp setlib -name xilffs
bsp setlib -name xilflash
bsp setlib -name xilpm
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
bsp regenerate

domain active {zynqmp_pmufw}
bsp setlib -name xilfpga
bsp setlib -name xilskey
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
bsp regenerate

domain active {standalone_domain}
bsp setlib -name xilffs
bsp setlib -name xilpm
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
bsp regenerate

platform write
platform generate

app create -name ultrascale_hello_world -platform ultrascale_platform -domain standalone_domain -template {Hello World}
app config -name ultrascale_hello_world build-config Release
