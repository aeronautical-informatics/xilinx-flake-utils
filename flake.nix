{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.devshell.url = "github:numtide/devshell";

  outputs = { self, nixpkgs, flake-utils, ... } @ inputs:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (self: super: { xilinx = xilinx-packages; })
            inputs.devshell.overlay
          ];
        };

        # taken from
        # https://github.com/nix-community/nix-environments
        genFhs = { name ? "xilinx-fhs", runScript ? "bash", profile ? "" }: pkgs.buildFHSUserEnv {
          inherit name runScript profile;
          targetPkgs = pkgs: with pkgs; [
            bash
            coreutils
            zlib
            lsb-release
            stdenv.cc.cc
            ncurses5
            xorg.libXext
            xorg.libX11
            xorg.libXrender
            xorg.libXtst
            xorg.libXi
            xorg.libXft
            xorg.libxcb
            xorg.libxcb
            # common requirements
            freetype
            fontconfig
            glib
            gtk2
            gtk3

            # to compile some xilinx examples
            opencl-clhpp
            ocl-icd
            opencl-headers

            # from installLibs.sh
            graphviz
            (lib.hiPrio gcc)
            unzip
            nettools
          ];
          multiPkgs = null;
        };
        versions = builtins.fromTOML (builtins.readFile ./versions.toml);
        genProductList = products: builtins.concatStringsSep "," (
          pkgs.lib.mapAttrsToList (name: value: if value then "${name}:1" else "${name}:0")
            products);
        build-xilinx-toolchain = { name, src, edition, products, version }:
          let
            nameLowercase = pkgs.lib.toLower name;
            fhsName = nameLowercase + "-fhs";
            toolchain-raw = pkgs.stdenv.mkDerivation rec {
              inherit src version;
              pname = nameLowercase + "-raw";
              nativeBuildInputs = with pkgs; [ xorg.xorgserver (genFhs { }) ];
              dontStrip = true;
              dontPatchELF = true;
              noAuditTmpdir = true;
              dontPruneLibtoolFiles = true;
              installPhase = ''
                runHook preInstall

                substitute ${./assets/install_config.txt} install_config.txt \
                  --subst-var-by edition '${edition}' --subst-var out \
                  --subst-var-by products '${genProductList products}'

                export DISPLAY=:1
                Xvfb $DISPLAY &
                xvfb_pid=$!
                xilinx-fhs xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
                  --batch Install --config install_config.txt
                kill $xvfb_pid

                runHook postInstall
              '';
            };
            wrapper = pkgs.runCommand (nameLowercase + "-wrapped") { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
              mkdir -p $out/bin
              for dir in $(find ${toolchain-raw}/ -maxdepth 3 -type f -name 'settings64.sh' -exec dirname {} \;)
              do
                for file in $(find "$dir" -maxdepth 2 -path '*/bin/*' -type f -executable)
                do
                  makeWrapper \
                      "${genFhs { runScript = ""; }}/bin/xilinx-fhs" \
                      "$out/bin/''${file##*/}" \
                      --run "$dir/settings64.sh" \
                      --set LC_NUMERIC 'en_US.UTF-8' \
                      --add-flags "\"$file\""
                done
              done
            '';
          in
          wrapper;

        xilinx-packages = builtins.listToAttrs
          (pkgs.lib.flatten (pkgs.lib.mapAttrsToList
            (version: { editions, products, sha256 }: builtins.map
              (edition: pkgs.lib.nameValuePair
                (pkgs.lib.toLower (
                  builtins.replaceStrings [ " " "." ] [ "-" "-" ] "${edition}-${version}"
                ))
                (build-xilinx-toolchain {
                  name = builtins.elemAt (pkgs.lib.splitString "_" version) 0;
                  src = pkgs.requireFile {
                    name = "Xilinx_${version}.tar.gz";
                    url = "https://www.xilinx.com/";
                    inherit sha256;
                  };
                  inherit edition products version;
                })
              )
              editions
            )
            versions));
      in
      rec {
        packages = {
          fhs = genFhs { runScript = ""; };
        } // xilinx-packages;

        checks = {
          nixpkgs-fmt = pkgs.runCommand "nixpkgs-fmt" { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; }
            "nixpkgs-fmt --check ${./.}; touch $out";
          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; }
            "shellcheck ${./utils.sh}; touch $out";
        };

        devShells.default = pkgs.devshell.mkShell {
          imports = [ "${inputs.devshell}/extra/git/hooks.nix" ];
          name = "xilinx-dev-shell";
          packages = [
            pkgs.coreutils
            pkgs.glow
            pkgs.python3
            xilinx-packages.vitis-unified-software-platform-vitis_2019-2_1106_2127
          ];
          git.hooks = {
            enable = true;
            pre-commit.text = ''
              nix flake check
            '';
          };
          commands =
            let
              commandTemplate = command: ''
                set +u
                source "$PRJ_ROOT/utils.sh"
                ${command} ''${@}
              '';
            in
            [
              {
                name = "help";
                command = ''glow "$PRJ_ROOT/README.md"'';
                help = "";
              }
              {
                name = "create-project";
                command = commandTemplate "create-project";
                help = "creates a new project based on a template";
              }
              {
                name = "store";
                command = commandTemplate "store";
                help = "create a restore script for a given project";
              }
              {
                name = "restore";
                command = commandTemplate "restore";
                help = "restore a project using a generated restore script";
              }
              {
                name = "generate-hw-config";
                command = commandTemplate "generate-hw-config";
                help = "generate a hw config for given platform";
              }
              {
                name = "build-bootloader";
                command = commandTemplate "build-bootloader";
                help = "build the bootloader for a script";
              }
              {
                name = "jtag-boot";
                command = commandTemplate "jtag-boot";
                help = "deploy a firmware via jtag";
              }
              {
                name = "launch-picocom";
                command = ''
                  picocom --imap lfcrlf --baud 115200 ''${1:-/dev/ttyUSB1}
                '';
                help = "launch picocom";
              }
            ];
        };

        # just add every package as a hydra job
        hydraJobs = packages;
      }
    );
}
