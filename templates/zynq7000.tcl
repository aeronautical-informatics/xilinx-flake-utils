#!/usr/bin/env xsct

if { $argc != 2 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name proj_dir proj_name"
	exit 0
}

set ::proj_dir [lindex $argv 0]
set ::proj_name [lindex $argv 1]

set version [version -short]

if { ${version} eq "2019.2" } {
    #source zynq7000_v2019_2.tcl $proj_dir $proj_name
    source zynq7000_v2019_2
} elseif { ${version} eq "2022.2.2" } {
    #source zynq7000_v2022_2.tcl $proj_dir $proj_name
    source "zynq7000_v2022_2.tcl"
} else {
    puts "Error: Installed Vivado version < ${version} > is not supported!"
}