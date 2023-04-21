#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace xsa_file"
	exit 0
}

set workspace [lindex $argv 0]
set xsa_file [lindex $argv 1]

setws $workspace

platform create -name {ultrascale_fsbl_platform} -hw $xsa_file\
    -proc {psu_cortexa53_0} -os {standalone} -out $workspace

platform active {ultrascale_fsbl_platform}

domain active {zynqmp_fsbl}
bsp setlib -name xilffs
bsp setlib -name xilflash
bsp setlib -name xilpm
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
#bsp config hypervisor_guest true
bsp regenerate

domain active {zynqmp_pmufw}
bsp setlib -name xilfpga
bsp setlib -name xilskey
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp false
bsp regenerate

domain active {standalone_domain}
bsp setlib -name xilffs
bsp setlib -name xilpm
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
bsp regenerate

platform write
platform generate

platform create -name {ultrascale_fsbl_flash_platform} -hw $xsa_file\
    -proc {psu_cortexa53_0} -os {standalone} -out $workspace

platform active {ultrascale_fsbl_flash_platform}

domain active {zynqmp_fsbl}
bsp setlib -name xilffs
bsp setlib -name xilflash
bsp setlib -name xilpm
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
#bsp config hypervisor_guest true
bsp regenerate

domain active {zynqmp_pmufw}
bsp setlib -name xilfpga
bsp setlib -name xilskey
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp false
bsp regenerate

domain active {standalone_domain}
bsp setlib -name xilffs
bsp setlib -name xilpm
bsp setlib -name xilsecure
bsp config zynqmp_fsbl_bsp true
bsp regenerate

platform write
platform generate

# fsbl standard application
#app create -name fsbl_standard_ultrascale -platform ultrascale_platform -domain standalone_domain -template {ZynqMP FSBL}
#app config -name fsbl_standard_ultrascale build-config Release
#app build fsbl_standard_ultrascale

# fsbl modified application (used to load sw in flash)
#app create -name fsbl_modified_ultrascale -platform ultrascale_platform -domain standalone_domain -template {ZynqMP FSBL}
#app config -name fsbl_modified_ultrascale build-config Release
