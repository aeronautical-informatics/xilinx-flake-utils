# **********************************************************
# Author: Phillip Nöldeke (DLR-FT-SSY)
# Date: 2021/11/29
# **********************************************************

# set project name variable
set proj_name $name

# Set the reference directory for source file relative paths
set origin_dir [file dirname [file normalize [info script]]]

# remove wrapper file from project and update compile order
export_ip_user_files -of_objects [get_files "$origin_dir/../hdl/${proj_name}_BD_wrapper.vhd"] -no_script -reset -force -quiet
remove_files "$origin_dir/../hdl/${proj_name}_BD_wrapper.vhd"

# create new wrapper file
make_wrapper -files [get_files "$origin_dir/../workspace/${proj_name}.srcs/sources_1/bd/${proj_name}_BD/${proj_name}_BD.bd"] -top

# copy wrapper file in /${proj_name}/hdl/ directory
file copy -force "$origin_dir/../workspace/${proj_name}.srcs/sources_1/bd/${proj_name}_BD/hdl/${proj_name}_BD_wrapper.vhd" "$origin_dir/../hdl/${proj_name}_BD_wrapper.vhd"

# add /hdl/wrapper.vhd file to project
add_files -norecurse "$origin_dir/../hdl/${proj_name}_BD_wrapper.vhd"
update_compile_order -fileset sources_1

# generate block design
generate_target all [get_files  $origin_dir/../workspace/${proj_name}.srcs/sources_1/bd/${proj_name}_BD/${proj_name}_BD.bd]
export_ip_user_files -of_objects [get_files $origin_dir/../workspace/${proj_name}.srcs/sources_1/bd/${proj_name}_BD/${proj_name}_BD.bd] -no_script -sync -force -quiet
export_simulation -of_objects [get_files $origin_dir/../workspace/${proj_name}.srcs/sources_1/bd/${proj_name}_BD/${proj_name}_BD.bd] -directory $origin_dir/../workspace/${proj_name}.ip_user_files/sim_scripts -ip_user_files_dir $origin_dir/../workspace/${proj_name}.ip_user_files -ipstatic_source_dir $origin_dir/../workspace/${proj_name}.ip_user_files/ipstatic -lib_map_path [list {modelsim=$origin_dir/../workspace/${proj_name}.cache/compile_simlib/modelsim} {questa=$origin_dir/../workspace/${proj_name}.cache/compile_simlib/questa} {ies=$origin_dir/../workspace/${proj_name}.cache/compile_simlib/ies} {xcelium=$origin_dir/../workspace/${proj_name}.cache/compile_simlib/xcelium} {vcs=$origin_dir/../workspace/${proj_name}.cache/compile_simlib/vcs} {riviera=$origin_dir/../workspace/${proj_name}.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet
