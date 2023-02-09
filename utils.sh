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


#
### Helper functions ###
#

# Args:
# $1 level
# $2 message
# $3 return code, if termination is desired
log(){
  local RED='\e[31m'
  local GREEN='\e[32m'
  local BOLD='\e[1m'
  local RESET='\e[0m'
  case "$1" in
    info)
      echo -e "${BOLD}[${GREEN}INFO${RESET}${BOLD}]${RESET}  ${2//\\n/\n        }"
    ;;
    error)
      echo -e "${BOLD}[${RED}ERROR${RESET}${BOLD}]${RESET} ${2//\\n/\n        }"
    ;;
    usage)
      echo -e "usage: $2\n"
      for line in "${@:3}"
      do
        echo -e "$line"
      done
      exit 0
    ;;
    *)
      log error "unknown loglevel $1" 1
    ;;
  esac

  if [[ "$#" -ge 3 ]]
  then
    exit "$3"
  fi
}

# ensures that $1 is a file.
#
# arguments: file|dir <variable name> <path>
#
# behavior codes
# exit 1: terminates with return code 1 if $1 is not a valid variable name
# exit 127: terminates with return code 127 if $2 is not a file/dir
# exit 0: stores the path to $2 in a variable with the name of $1
_ensure-exists(){
  local TYPE="$1"
  local VARIABLE_NAME="$2"
  local PATH="$3"

  # check that variable name is a valid variable name
  [[ "$VARIABLE_NAME" =~ ^[_[:alpha:]][_[:alpha:][:digit:]]*$ ]] || {
    log error "the variable name '$1' is not valid" 1
  }

  if [[ "$TYPE" == file ]] && [[ ! -f "$PATH" ]]
  then
    log error "the $VARIABLE_NAME $TYPE '$PATH' could not be found" 127
  fi

  if [[ "$TYPE" == dir ]] && [[ ! -d "$PATH" ]]
  then
    log error "the $VARIABLE_NAME $TYPE '$PATH' could not be found" 127
  fi

  eval "$VARIABLE_NAME='$PATH'"
}

# checks that $1 does not exist, terminating with return code 1 after printing $2 on violation
_ensure-exists-not(){
  if [[ -e "$1" ]]
  then
    log error "'$1' already exists\n$2" 1
  fi
}

# for each argument, ensure it  exists and is a directory, creating it if necessary
# fail if any argument already exists but is not a dir
_mkdir-if-missing(){
  for dir in "$@"
  do
    # it is a dir, everything fine
    [[ -d "$dir" ]] && continue

    # it does not exist, create it
    [[ -e "$dir" ]] || {
      log info "the dir '$dir' does not exist; creating it"
      mkdir --parent -- "$dir"
      continue
    }

    # it does exist and is not a dir
    log error "'$dir' exists but is not a directory, terminating" 1
  done
}

# updates wrapper file of Vivado project
_update-wrapper(){
  [[ "$#" == 2 ]] || log usage "update-wrapper PROJ_DIR PROJ_NAME"

  local PROJ_DIR="$1"
  local PROJ_NAME="$2"

  python3 "$UTILS_ROOT/templates/set_update_wrapper.py" "$PROJ_DIR/$PROJ_NAME" "$PROJ_NAME"
}

# cleans up build artifacts from viviad & vitis
_clean_up(){
  [[ -d ".Xil/" ]] &&  rm --recursive .Xil/
}


#
### Functions made to be used externally ###
#

# creates a project from a template
create-project(){
  [[ "$#" == 3 ]] || log usage "create-project TEMPLATE PROJ_DIR PROJ_NAME" \
    "available TEMPLATEs are: zynq7000, ultrascale, zedboard, coraz7"

  _ensure-exists file SCRIPT "$UTILS_ROOT/templates/$1.tcl"
  local PROJ_DIR="$2"
  local PROJ_NAME="$3"
  _ensure-exists-not "$PROJ_DIR/$PROJ_NAME" "Please delete existing project..."
  _mkdir-if-missing "$PROJ_DIR/$PROJ_NAME/"{workspace,constr,hdl,scripts}

  cp "$UTILS_ROOT/templates/.gitignore" "$PROJ_DIR/$PROJ_NAME"
  echo -e "# README for the '$PROJ_NAME' FPGA project\n" > "$PROJ_DIR/$PROJ_NAME/README.md"

  _update-wrapper "$PROJ_DIR" "$PROJ_NAME"

  vivado -nolog -nojournal -mode batch -source "$SCRIPT" -tclargs "$PROJ_DIR" "$PROJ_NAME"
}


# stores a Vivado project
store(){
  [[ "$#" == 1 ]] || log usage "usage: store PROJ_DIR"

  _ensure-exists file PROJ_FILE "$1/workspace"/*.xpr
  _ensure-exists file SCRIPT "$UTILS_ROOT/tcl-lib/store.tcl"

  vivado -nolog -nojournal -mode batch -source "$SCRIPT" "$PROJ_FILE"
}


# restores a project from a template script
restore(){
  [[ "$#" == 1 ]] || log usage "restore PROJ_DIR"

  _ensure-exists dir PROJ_DIR "$1"
  _ensure-exists "$PROJ_DIR/scripts/restore.tcl"
  _ensure-exists-not "$PROJ_DIR/workspace" "The workspace '$PROJ_DIR/workspace/' already exists" \
    "Please delete it manually before restoring the project."

  pushd "$PROJ_DIR" || return 1
  vivado -nolog -nojournal -mode batch -source "$SCRIPT"
  [[ -d ".Xil/" ]] && rm -r .Xil/

  # shellcheck disable=SC2164
  popd
}

# generates the harwdare configuration for a fpga project
# Note: WORKSPACE_DIR must contain a subdir `workspace`
generate-hw-config(){
  [[ "$#" == 1 ]] || log usage "generate-hw-config PROJ_DIR"

  _ensure-exists dir  PROJ_DIR "$1"
  _ensure-exists file PROJ_FILE "$PROJ_DIR/workspace/"*.xpr
  _mkdir-if-missing "$PROJ_DIR/hardware_configuration"

  vivado -nolog -nojournal -mode batch \
    -source "$UTILS_ROOT/tcl-lib/vivado_all.tcl" "$PROJ_FILE" \
    -tclargs "$PROJ_DIR/hardware_configuration"
}

# generates the bootloader for a fpga project
build-bootloader(){
  [[ "$#" == 2 ]] || log usage "build-bootloader PLATFORM PROJ_DIR" \
    "available platforms are: zynq7000, zedboard, ultrascale, coraz7"

  local PLATFORM="$1"
  _ensure-exists dir PROJ_DIR "$2"
  _ensure-exists file SCRIPT "$UTILS_ROOT/tcl-lib/vitis_platform_$PLATFORM.tcl"
  _ensure-exists file XSA "$PROJ_DIR/hardware_configuration/hw_export.xsa"

  if [[ -d "$PROJ_DIR/bootloader_configuration" ]] || [[ -d "$PROJ_DIR/bootloader_export" ]]
  then
    rm --recursive --force -- "$PROJ_DIR/"{bootloader_configuration,bootloader_export}
  fi

  _mkdir-if-missing "$PROJ_DIR/"{bootloader_configuration,bootloader_export}

  xsct "$SCRIPT" "$PROJ_DIR/bootloader_configuration" "$XSA"

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
  [[ "$#" == 3 ]] || log usage "jtag-boot HW_PLATFORM PROJ_DIR ELF" \
    "available hw platforms are: zynq7000, coraz7, zedboard, ultrascale"

  local HW_PLATFORM="$1"
  _ensure-exists file SCRIPT "$UTILS_ROOT/tcl-lib/jtag_boot/${HW_PLATFORM}_init.tcl"
  _ensure-exists dir PROJ_DIR "$2"
  _ensure-exists file XSA "$(find "$PROJ_DIR" -name hw_export.xsa | head -n 1)"
  _ensure-exists file ELF "$3"

  local XSA_TMP_DIR
  XSA_TMP_DIR=$(mktemp --directory -- "/tmp/$HW_PLATFORM-xsa-XXXXXXXXXX")
  unzip -d "$XSA_TMP_DIR" -qq -- "$XSA"
  log info "extracted XSA to $XSA_TMP_DIR"

  _ensure-exists file BITSTREAM "$XSA_TMP_DIR/hw_export.bit"

  # the different HW platforms differ in their initialization, thus a switch case
  case "$HW_PLATFORM" in
    "zynq7000"|"zedboard"|"coraz7")
      _ensure-exists file PS7 "$XSA_TMP_DIR/ps7_init.tcl"

      xsct "$SCRIPT" "$PS7" "$BITSTREAM" "$XSA" "$ELF"
    ;;

    "ultrascale")
      _ensure-exists file PMUFW "$(find "$PROJ_DIR" -name pmufw_ultrascale.elf | head -n 1)"
      _ensure-exists file FSBL "$(find "$PROJ_DIR" -name fsbl_ultrascale.elf | head -n 1)"
      _ensure-exists file ZYNQMP_UTILS "$(find "$UTILS_ROOT/tcl-lib" -name zynqmp_utils.tcl | head -n 1)"

      xsct "$SCRIPT" "$BITSTREAM" "$XSA" "$PMUFW" "$FSBL" "$ZYNQMP_UTILS" "$ELF"
    ;;

    *)
      log error "unsupported platform $HW_PLATFORM" 1
    ;;
  esac

  rm --recursive -- "$XSA_TMP_DIR"
}