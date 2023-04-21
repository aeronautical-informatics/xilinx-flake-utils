#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace platform_name"
	exit 0
}

set workspace [lindex $argv 0]
set platform_name [lindex $argv 1]

## set workspace
setws $workspace

## Regenerate the platform
platform active $platform_name

platform write
platform generate
