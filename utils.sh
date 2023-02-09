#!/usr/bin/env bash

# Utils script to build a hardware configuration for a selected platform and boot it on a hardware.
# Please source this script at first before usage.
# Then the following functions can be used:
# 'create-project', 'store', 'restore', 'generate-hw-config', 'build-bootloader', 'jtag-boot'

UTILS_ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# check if the libs and files are present
if [[ ! -d "$UTILS_ROOT/tcl-lib" ]] && [[ ! -d "$UTILS_ROOT/templates" ]]
then
  echo "you must set UTILS_ROOT before sourcing this script"
  return 1
fi


# TODO add a check for xsct, vivado and vitis to be present
# TODO add check that UTILS_ROOT is absolute


# creates a project from a template
create-project(){
  [[ "$#" == 3 ]] || {
    echo; echo "usage: create-project TEMPLATE PROJ_DIR PROJ_NAME"
    echo "available TEMPLATEs are: zynq7000, ultrascale, zedboard, coraz7"; echo
    return 0
  }

  local TEMPLATE="$1"
  local PROJ_DIR="$2"
  local PROJ_NAME="$3"
  local SCRIPT="$UTILS_ROOT/templates/$TEMPLATE.tcl"

  [[ -f "$SCRIPT" ]] || {
    echo; echo "The template script '$SCRIPT' could not be found."; echo
    return 1
  }

  [[ -d "$PROJ_DIR" ]] || {
    echo; echo "The project directory '$PROJ_DIR' does not exist; creating it"; echo
    mkdir --parent -- "$PROJ_DIR"
  }

  if [[ -d "$PROJ_DIR/$PROJ_NAME" ]]
  then
    echo "Delete existing project..."; echo
    # rm --recursive --force -- "$PROJ_DIR/$PROJ_NAME/"*
  fi

  mkdir --parent -- "$PROJ_DIR/$PROJ_NAME/"{workspace,constr,hdl,scripts}

  cp "$UTILS_ROOT/templates/.gitignore" "$PROJ_DIR/$PROJ_NAME"
  echo -e "# README for the '$PROJ_NAME' FPGA project\n" > "$PROJ_DIR/$PROJ_NAME/README.md"

  update-wrapper "$PROJ_DIR" "$PROJ_NAME"

  vivado -nolog -nojournal -mode batch -source "$SCRIPT" -tclargs "$PROJ_DIR" "$PROJ_NAME"
  echo; echo "Vivado project created."
}

# updates wrapper file of Vivado project
update-wrapper()
{
  [[ "$#" == 2 ]] || {
    echo; echo "usage: update-wrapper PROJ_DIR PROJ_NAME"; echo
    return 0
  }

  local PROJ_DIR="$1"
  local PROJ_NAME="$2"

  python3 "$UTILS_ROOT/templates/set_update_wrapper.py" "$PROJ_DIR/$PROJ_NAME" "$PROJ_NAME"
}

# stores a Vivado project
store(){
  [[ "$#" == 1 ]] || {
    echo; echo "usage: store PROJ_DIR"; echo
    return 0
  }

  local PROJ_DIR="$1"
  local WORKSPACE_DIR="$PROJ_DIR/workspace"
  local SCRIPT="$UTILS_ROOT/tcl-lib/store.tcl"

  [[ -d "$PROJ_DIR" ]] || {
    echo; echo "The project directory '$PROJ_DIR' does not exist."; echo
    return 127
  }

  [[ -d "$WORKSPACE_DIR" ]] || {
    echo; echo "The workspace directory '$WORKSPACE_DIR' does not exist."
    echo "Please try to restore the workspace before storing it."; echo
    return 127
  }

  vivado -nolog -nojournal -mode batch -source "$SCRIPT" "$WORKSPACE_DIR/"*.xpr
  [[ -d ".Xil/" ]] &&  rm --recursive .Xil/
}

# restores a project from a template script
restore(){
  [[ "$#" == 1 ]] || {
    echo; echo "usage: restore PROJ_DIR"; echo
    return 0
  }

  local PROJ_DIR="$1"
  local SCRIPT="$PROJ_DIR/scripts/restore.tcl"

  [[ -d "$PROJ_DIR" ]] || {
    echo; echo "The project directory '$PROJ_DIR' does not exist."; echo
    return 127
  }

  [[ -f "$SCRIPT" ]] || {
    echo; echo "The restore script '$SCRIPT' could not be found."
    echo "Please try store the project before restoring it."; echo
    return 1
  }

   if [ -d "$PROJ_DIR/workspace" ]
   then
    echo; echo "The workspace '$PROJ_DIR/workspace/' already exists."
    echo "Please delete it manually before restoring the project."; echo
    return 1
  fi

  pushd "$PROJ_DIR" || return 1
  vivado -nolog -nojournal -mode batch -source "$SCRIPT"
  [[ -d ".Xil/" ]]
    rm -r .Xil/

  # shellcheck disable=SC2164
  popd
}

# generates the harwdare configuration for a fpga project
# Note: WORKSPACE_DIR must contain a subdir `workspace`
generate-hw-config(){
  [[ "$#" == 1 ]] || {
    echo; echo "usage: generate-hw-config PROJ_DIR"; echo
    return 0
  }

  local PROJ_DIR="$1"

  [[ -d "$PROJ_DIR/workspace" ]] || {
    echo; echo "The workspace directory '$PROJ_DIR/workspace' does not exist."
    echo "Please try to restore the project before generating the hardware configuration."; echo
    return 127
  }

  mkdir --parent -- "$PROJ_DIR/hardware_configuration"

  vivado -nolog -nojournal -mode batch \
    -source "$UTILS_ROOT/tcl-lib/vivado_all.tcl" \
    "$PROJ_DIR/workspace/"*.xpr -tclargs "$PROJ_DIR/hardware_configuration"
}

# generates the bootloader for a fpga project
build-bootloader(){
  [[ "$#" == 2 ]] || {
    echo "usage: build-bootloader PLATFORM PROJ_DIR"
    echo "available platforms are: zynq7000, zedboard, ultrascale, coraz7"; echo
    return 0
  }

  local PLATFORM="$1"
  local PROJ_DIR="$2"

  [[ -f "$UTILS_ROOT/tcl-lib/vitis_platform_$PLATFORM.tcl" ]] || {
    echo; echo "Unknown platform $PLATFORM."; echo
    return 1
  }

  [[ -d "$PROJ_DIR" ]] || {
    echo; echo "PROJ_DIR '$OUT_DIR' does not exist."; echo
    return 127
  }

  [[ -f "$PROJ_DIR/hardware_configuration/hw_export.xsa" ]] || {
    echo; echo "Hardware configuration does not exist."; echo
    return 127
  }

  if [[ -d "$PROJ_DIR/bootloader_configuration" ]] || [[ -d "$PROJ_DIR/bootloader_export" ]]
  then
    rm --recursive --force -- "$PROJ_DIR/"{bootloader_configuration,bootloader_export}
  fi

  mkdir --parent -- "$PROJ_DIR/"{bootloader_configuration,bootloader_export}

  xsct "$UTILS_ROOT/tcl-lib/vitis_platform_$PLATFORM.tcl" "$PROJ_DIR/bootloader_configuration" "$PROJ_DIR/hardware_configuration/"*.xsa

  if [[ "$PLATFORM" == "ultrascale" ]]
  then
    cp "$PROJ_DIR/bootloader_configuration/ultrascale_platform/hw/psu_init.tcl" "$PROJ_DIR/bootloader_export/"
	  cp "$PROJ_DIR/bootloader_configuration/ultrascale_platform/export/ultrascale_platform/sw/ultrascale_platform/boot/fsbl.elf" "$PROJ_DIR/bootloader_export/fsbl_ultrascale.elf"
	  cp "$PROJ_DIR/bootloader_configuration/ultrascale_platform/export/ultrascale_platform/sw/ultrascale_platform/boot/pmufw.elf" "$PROJ_DIR/bootloader_export/pmufw_ultrascale.elf"
    cp "$UTILS_ROOT/utils/fsbl_flash_ultrascale.elf" "$PROJ_DIR/bootloader_export/"
  else
    cp "$PROJ_DIR/bootloader_configuration/${PLATFORM}_platform/hw/ps7_init.tcl" "$PROJ_DIR/bootloader_export/"
    cp "$PROJ_DIR/bootloader_configuration/fsbl_standard_$PLATFORM/Release/fsbl_standard_$PLATFORM.elf" "$PROJ_DIR/bootloader_export/fsbl_$PLATFORM.elf"
  fi

  if [[ "$PLATFORM" == "zynq7000" ]]
  then
    # apply patch to fsbl_modified version
    pushd "$PROJ_DIR/bootloader_configuration/fsbl_standard_zynq7000/src/" || return 1
    patch < "$UTILS_ROOT/tcl-lib/disable_ddr_use_always_jtag_zynq7000.patch"

    # shellcheck disable=SC2164
    popd

    xsct "$UTILS_ROOT/tcl-lib/modified_fsbl_zynq7000.tcl" "$PROJ_DIR/bootloader_configuration"
    cp "$PROJ_DIR/bootloader_configuration/fsbl_modified_zynq7000/Release/fsbl_modified_zynq7000.elf" "$PROJ_DIR/bootloader_export/fsbl_flash_zynq7000.elf"
  #elif [[ "$PLATFORM" == "zedboard" ]]
  #then
  #  echo "currently not supported"
  fi
}

# boot an image via jtag
jtag-boot(){
  [[ "$#" == 3 ]] || {
    echo "usage: jtag-boot HW_PLATFORM PROJECT_DIR ELF"
    echo "available hw platforms are: zynq7000, coraz7, zedboard, ultrascale"; echo
    return 0
  }

  local HW_PLATFORM="$1"
  local PROJECT_DIR="$2"
  local ELF="$3"

  [[ -f "$UTILS_ROOT/tcl-lib/jtag_boot/${HW_PLATFORM}_init.tcl" ]] || {
    echo "unknown HW_PLATFORM $HW_PLATFORM"
    return 1
  }

  local BITSTREAM
  BITSTREAM=$(find "$PROJECT_DIR" -name bitstream_export.bit | head -n 1)
  if [[ -f "$BITSTREAM" ]]
  then
    echo "found bitstream file '$BITSTREAM'"
  else
    echo "bitstream file '$BITSTREAM' not found"
    return 127
  fi

  local XSA
  XSA=$(find "$PROJECT_DIR" -name hw_export.xsa | head -n 1)
  if [[ -f "$XSA" ]]
  then
    echo "found xsa file '$XSA'"
  else
    echo "xsa file '$XSA' not found"
    return 127
  fi

  [[ -f "$ELF" ]] || {
    echo "ELF file '$ELF' not found"
    return 127
  }

  if [[ "$HW_PLATFORM" == "zynq7000" ]]
  then
    # needed: ps7_init.tcl
    # bitstream
    # hw_export.xsa
    # elf
    local PS7_FILE
    PS7_FILE=$(find "$PROJECT_DIR" -name ps7_init.tcl | head -n 1)
    if [[ -f "$PS7_FILE" ]]
    then
      echo "found ps7_init file '$PS7_FILE'"
    else
      echo "PS7 file '$PS7_FILE' not found"
      return 127
    fi

    xsct "$UTILS_ROOT/tcl-lib/jtag_boot/${HW_PLATFORM}_init.tcl" "$PS7_FILE" "$BITSTREAM" "$XSA" "$ELF"

  elif [[ "$HW_PLATFORM" == "ultrascale" ]]
  then
    # needed: zynqmp_utils.tcl
    # bitstream
    # hw_export.xsa
    # pmufw_ultrascale.elf
    # fsbl_ultrascale.elf
    # zynqmp_utils.tcl
    # elf
    local PMUFW_FILE
    PMUFW_FILE=$(find "$PROJECT_DIR" -name pmufw_ultrascale.elf | head -n 1)
    if [[ -f "$PMUFW_FILE" ]]
    then
      echo "found pmufw_ultrascale file '$PMUFW_FILE'"
    else
      echo "pmufw_ultrascale file '$PMUFW_FILE' not found"
      return 127
    fi

    local FSBL_FILE
    FSBL_FILE=$(find "$PROJECT_DIR" -name fsbl_ultrascale.elf | head -n 1)
    if [[ -f "$FSBL_FILE" ]]
    then
      echo "found fsbl_ultrascale file '$FSBL_FILE'"
    else
      echo "fsbl_ultrascale file '$FSBL_FILE' not found"
      return 127
    fi

    local ZYNQMP_UTILS
    ZYNQMP_UTILS=$(find "$UTILS_ROOT/tcl-lib" -name zynqmp_utils.tcl | head -n 1)
    if [[ -f "$ZYNQMP_UTILS" ]]
    then
      echo "found zynqmp_utils file '$ZYNQMP_UTILS'"
    else
      echo "zynqmp_utils file '$ZYNQMP_UTILS' not found"
      return 127
    fi

    xsct "$UTILS_ROOT/tcl-lib/jtag_boot/${HW_PLATFORM}_init.tcl" "$BITSTREAM" "$XSA" "$PMUFW_FILE" "$FSBL_FILE" "$ZYNQMP_UTILS" "$ELF"

  elif [[ "$HW_PLATFORM" == "zedboard" ]]
  then
    # needed: ps7_init.tcl
    # bitstream
    # hw_export.xsa
    # elf
    local PS7_FILE
    PS7_FILE=$(find "$PROJECT_DIR" -name ps7_init.tcl | head -n 1)
    if [[ -f "$PS7_FILE" ]]
    then
      echo "found ps7_init file '$PS7_FILE'"
    else
      echo "PS7 file '$PS7_FILE' not found"
      return 127
    fi

    xsct "$UTILS_ROOT/tcl-lib/jtag_boot/${HW_PLATFORM}_init.tcl" "$PS7_FILE" "$BITSTREAM" "$XSA" "$ELF"

  elif [[ "$HW_PLATFORM" == "coraz7" ]]
  then
    # needed: ps7_init.tcl
    # bitstream
    # hw_export.xsa
    # elf
    # TODO implement the rest
    echo "currently unsupported"
    return 1
  else
    echo "unsupported platform $HW_PLATFORM"
    return 1
  fi
}