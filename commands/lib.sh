#!/usr/bin/env bash

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

  awk -v name="$PROJ_NAME" '/set proj_name/{gsub("\\$name","{"name"}")}1' \
    "$UTILS_ROOT/templates/update_wrapper_template.tcl" > \
    "$PROJ_DIR/$PROJ_NAME/scripts/update_wrapper.tcl"
}

# cleans up build artifacts from viviad & vitis
_clean_up(){
  [[ -d ".Xil/" ]] &&  rm --recursive .Xil/
}
