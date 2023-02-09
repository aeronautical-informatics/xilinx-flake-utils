#!/usr/bin/env xsct

# writes a restore script

set proj_dir [get_property DIRECTORY [current_project]]
set output_dir "$proj_dir/../scripts/"

write_project_tcl -force -origin_dir_override "scripts" -target_proj_dir "workspace" "$output_dir/restore.tcl"