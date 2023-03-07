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

## Rebuild the modified project
app build fsbl_modified_${platform}
