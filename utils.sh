#!/usr/bin/env bash


# check if the libs and files are present
if [[ ! -d "$UTILS_ROOT" ]]
then
  echo "you must set UTILS_ROOT before sourcing this script"
  return 1
fi
# TODO add a check for xsct, vivado and vitis to be present
# TODO add check that UTILS_ROOT is absolute


# restores a project from a template script
restore(){
  [[ "$#" == 2 ]] || {
    echo "usage: restore PLATFORM OUT_DIR"
    echo "available PLATFORMSs are:"
    find "$UTILS_ROOT/fpga_projects/" -mindepth 1 -maxdepth 1 -type d -printf '- %P\n'
    return 0
  }

  local PLATFORM="$1"
  local OUT_DIR="$2"
  local SCRIPT="$UTILS_ROOT/fpga_projects/$PLATFORM/scripts/restore.tcl"

  [[ -f "$SCRIPT" ]] || {
    echo "platform script '$SCRIPT' could not be found"
    return 1
  }

  [[ -d "$OUT_DIR" ]] || {
    echo "OUT_DIR '$OUT_DIR' does not exist; creating it"
    mkdir --parent -- "$OUT_DIR"
  }

  cp -r "$UTILS_ROOT/fpga_projects/$PLATFORM/hdl" "$OUT_DIR/"
  chmod -R u+w -- "$OUT_DIR"

  pushd "$OUT_DIR" || return 1
  vivado -mode batch -source "$SCRIPT"

  # shellcheck disable=SC2164
  popd
}

# creates a restore script for the project in $WORKSPACE_DIR, writing the script to $TARGET_DIR
create-restore-script(){
  [[ "$#" == 3 ]] || {
    echo "usage: create-restore-script PLATFORM WORKSPACE_DIR OUT_DIR"
    echo "available PLATFORMSs are:"
    find "$UTILS_ROOT/fpga_projects/" -mindepth 1 -maxdepth 1 -type d -printf '- %P\n'
    return 0
  }

  local PLATFORM="$1"
  local WORKSPACE_DIR
  WORKSPACE_DIR=$(realpath "$2")
  local OUT_DIR="$3"
  local SCRIPT="$UTILS_ROOT/fpga_projects/$PLATFORM/scripts/create_restore_script.tcl"

  [[ -f "$SCRIPT" ]] || {
    echo "platform script '$SCRIPT' could not be found"
    return 1
  }

  [[ -d "$OUT_DIR" ]] || {
    echo "OUT_DIR '$OUT_DIR' does not exist; creating it"
    mkdir --parent -- "$OUT_DIR"
  }

  WORKSPACE_DIR="$WORKSPACE_DIR/workspace"

  [[ -d "$WORKSPACE_DIR" ]] && {
    echo "the directory '$WORKSPACE_DIR' does not exist"
    return 127
  }

  pushd "$OUT_DIR" || return 1
  vivado -mode batch -source "$UTILS_ROOT/fpga_projects/$PLATFORM/scripts/create_restore_script.tcl" "$WORKSPACE_DIR/"*.xpr

  # shellcheck disable=SC2164
  popd
}

# Note: WORKSPACE_DIR must contain a subdir `workspace`
generate-hw-config(){
  [[ "$#" == 2 ]] || {
    echo "usage: generate-hw-config WORKSPACE_DIR OUT_DIR"
    return 0
  }

  local WORKSPACE_DIR="$1"
  local OUT_DIR="$2"

  [[ -d "$WORKSPACE_DIR" ]] || {
    echo "workspace dir '$WORKSPACE_DIR' does not exist"
    return 127
  }

  [[ -d "$OUT_DIR" ]] || {
    echo "OUT_DIR '$OUT_DIR' does not exist; creating it"
    mkdir --parent -- "$OUT_DIR"
  }

  vivado -nolog -nojournal -mode batch \
    -source "$UTILS_ROOT/deployment/scripts/tcl_lib/vivado_all.tcl" \
    "$WORKSPACE_DIR/"*.xpr -tclargs "$OUT_DIR"
}

# Note: WORKSPACE_DIR must contain a subdir `workspace`
build-bootloader(){
  [[ "$#" == 3 ]] || {
    echo "usage: build-bootloader PLATFORM XSA OUT_DIR"
    echo "available platforms are:"
    find "$UTILS_ROOT/deployment/scripts/tcl_lib/" -mindepth 1 -maxdepth 1 -type f -name 'vitis_platform_*.tcl' -printf '- %P\n'
    return 0
  }

  local PLATFORM="$1"
  local XSA="$2"
  local OUT_DIR="$3"

  [[ -f "$UTILS_ROOT/deployment/scripts/tcl_lib/$PLATFORM" ]] || {
    echo "unknown platform $PLATFORM"
    return 1
  }

  [[ -f "$XSA" ]] || {
    echo "xsa file '$XSA' does not exist"
    return 127
  }

  [[ -d "$OUT_DIR" ]] || {
    echo "OUT_DIR '$OUT_DIR' does not exist; creating it"
    mkdir --parent -- "$OUT_DIR"
  }

  xsct "$UTILS_ROOT/deployment/scripts/tcl_lib/$PLATFORM" "$XSA" "$OUT_DIR"
}

# boot an image via jtag
jtag-boot(){
  [[ "$#" == 3 ]] || {
    echo "usage: jtag-boot HW_PLATFORM PROJECT_DIR ELF"
    echo "available hw platforms are:"
    find "$UTILS_ROOT/deployment/scripts/tcl_lib/" -mindepth 1 -maxdepth 1 -type f -name '*init*.tcl' -printf '- %P\n'
    return 0
  }

  local HW_PLATFORM="$1"
  local PROJECT_DIR="$2"
  local ELF="$3"

  [[ -f "$UTILS_ROOT/deployment/scripts/tcl_lib/$HW_PLATFORM" ]] || {
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

  if [[ "$HW_PLATFORM" == "zynq7000_init.tcl" ]]
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

    xsct "$UTILS_ROOT/deployment/scripts/tcl_lib/$HW_PLATFORM" "$PS7_FILE" "$BITSTREAM" "$XSA" "$ELF"

  elif [[ "$HW_PLATFORM" == "ultrascale_init.tcl" ]]
  then
    # needed: zynqmp_utils.tcl
    # bitstream
    # hw_export.xsa
    # pmufw_ultrascale.elf
    # fsbl_ultrascale.elf
    # elf
    # TODO implement the rest
    echo "currently unsupported"
    return 1
  else
    echo "unsupported platform $HW_PLATFORM"
    return 1
  fi
}
