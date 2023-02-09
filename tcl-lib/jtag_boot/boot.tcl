#!/usr/bin/env xsct

set jtag_id [dict get [lindex [ jtag targets -filter {level == 0} -target-properties] 0] name]

if { $jtag_id == "JTAG-ONB4 251633007674A" } {
	puts "jtag device: $jtag_id"	
	puts "no bootmode adaption needed"
} else {
	puts "jtag device: $jtag_id"	
	puts "boot mode adaption required"
}
