{ pkgs, toolchain, ... }:

let
  platforms = [ "zynq7000" "ultrascale" "zedboard" "coraz7" ];
in
builtins.genAttrs platforms (name:
pkgs.runCommandNoCC "check-${name}" { nativeBuildInputs = [ toolchain ]; } ''
  source ${./utils.sh}
  create-project ${name} $out ${name}_test_proj
  store $out/${name}_test_proj
  build-hw-config $out/${name}_test_proj
  build-bootloader ${name} $out/${name}_test_proj
  
'')
