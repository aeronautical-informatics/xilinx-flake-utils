#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace xsa_file"
	exit 0
}

set workspace [lindex $argv 0]
set xsa_file [lindex $argv 1]

setws $workspace

platform create -name {coraz7_platform} -hw $xsa_file \
	-proc {ps7_cortexa9_0} -os {standalone} -out $workspace

platform write

platform active {coraz7_platform}

domain active {zynq_fsbl}

domain active {standalone_domain}
bsp setlib -name xilffs
bsp regenerate

platform write
platform generate

app create -name coraz7_hello_world -platform coraz7_platform -domain standalone_domain -template {Hello World}
app config -name coraz7_hello_world build-config Release
