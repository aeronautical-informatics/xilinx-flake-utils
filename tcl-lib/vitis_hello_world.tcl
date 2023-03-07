#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace platform"
	exit 0
}

set workspace [lindex $argv 0]
set platform [lindex $argv 1]

## set workspace
setws $workspace

## clean the modified project
app clean fsbl_modified_${platform}

## Regenerate the platform
platform active ${platform}_platform
platform generate

app create -name ${platform}_hello_world -platform ${platform}_platform -domain standalone_domain -template {Hello World}
app config -name ${platform}_hello_world build-config Release
app build ${platform}_hello_world
