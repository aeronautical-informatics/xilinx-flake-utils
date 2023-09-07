#!/usr/bin/env xsct

if { $argc != 3 } {
	set prog_name [file tail $argv0]
    puts "usage: $prog_name proj_dir out_dir platform"
	exit 0
}

set proj_dir [lindex $argv 0]
set out_dir [lindex $argv 1]
set platform [lindex $argv 2]

set_property target_constrs_file "$proj_dir/constr/${platform}_constraints.xdc" [current_fileset -constrset]

# run synthesis
# Create a new run when it is not available
if {[llength [get_runs synth_automated]] == 0} {
    create_run synth_automated -flow {Vivado Synthesis 2019}
} else {
    # elsewise just reset the run
    reset_run synth_automated
}
#create_run synth_automated -flow {Vivado Synthesis 2019}

launch_runs synth_automated -jobs 10
wait_on_run synth_automated -quiet

# run implementation
# Create a new run when it is not available
if {[llength [get_runs impl_automated]] == 0} {
    create_run impl_automated -flow {Vivado Implementation 2019} -parent_run synth_automated
} else {
    # elsewise just reset the run
    reset_run impl_automated
}
#create_run impl_automated -flow {Vivado Implementation 2019} -parent_run synth_automated

launch_runs impl_automated -jobs 10
wait_on_run impl_automated -quiet

# run generate_bitstream
open_impl_design impl_automated
write_bitstream -force "$out_dir/${platform}_bitstream.bit"

# run export_hardware
open_impl_design impl_automated
write_hw_platform -force -fixed -include_bit -file "$out_dir/${platform}_hw.xsa"
