#!/usr/bin/env xsct

# Author: Phillip Noeldeke, German Aerospace Center (DLR) 2022

if { $argc != 1 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name workspace"
	exit 0
}

set workspace [lindex $argv 0]

## set workspace
setws $workspace

## clean the modified project
app clean fsbl_modified_zynq7000

## Regenerate the platform
platform active zynq7000_platform
platform generate

## Rebuild the modified project
app build fsbl_modified_zynq7000
