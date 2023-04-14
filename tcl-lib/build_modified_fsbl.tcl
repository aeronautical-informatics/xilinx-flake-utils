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

## clean the fsbl_jtag project
app clean fsbl_jtag_${platform}

## Regenerate the platform
platform active ${platform}_platform
platform generate

## Rebuild the fsbl_jtag project
app build fsbl_jtag_${platform}

## clean the fsbl_qspi project
app clean fsbl_qspi_${platform}

## Regenerate the platform
platform active ${platform}_platform
platform generate

## Rebuild the fsbl_qspi project
app build fsbl_qspi_${platform}

## clean the fsbl_flash project
app clean fsbl_flash_${platform}

## Regenerate the platform
platform active ${platform}_platform
platform generate

## Rebuild the fsbl_flash project
app build fsbl_flash_${platform}
