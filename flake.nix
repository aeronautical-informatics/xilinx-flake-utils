{
  description = "A collection of scripts for Xilinx Vitis/Vivado";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... } @ inputs:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        # checkout of the nixpkgs
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
            # runtime deps
            bash
            coreutils
            dbus
            procps
            which

            # libraries
            lsb-release
            ncurses5
            stdenv.cc.cc
            zlib

            # gui libraries
            fontconfig
            freetype
            glib
            gtk2
            gtk3
            xorg.libX11
            xorg.libXext
            xorg.libXft
            xorg.libXi
            xorg.libXrender
            xorg.libXtst
            xorg.libxcb
            xorg.libxcb
            xorg.xorgserver

            # compiler stuff to compile some xilinx examples
            ocl-icd
            opencl-clhpp
            opencl-headers

            # misc for installLibs.sh
            (lib.hiPrio gcc)
            graphviz
            nettools
            unzip
          ];
          multiPkgs = null;
        };

        # load known versions of Xilinx toolchains from the TOML
        versions = builtins.fromTOML (builtins.readFile ./versions.toml);

        # for each toolchain version, enumerate the available editions
        genProductList = products: builtins.concatStringsSep "," (
          pkgs.lib.mapAttrsToList (name: value: if value then "${name}:1" else "${name}:0")
            products);

        # build a Xilinx toolchain as a nix derivation
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

        # enumerate all packages buildable from the known versions, built using
        # `build-xilinx-toolchain`
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
        lib = {
          inherit build-xilinx-toolchain;
        };

        packages = {
          fhs = genFhs { runScript = ""; };
        } // xilinx-packages;

        checks = {
          nixpkgs-fmt = pkgs.runCommand "nixpkgs-fmt" { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; }
            "nixpkgs-fmt --check ${./.}; touch $out";
          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; }
            "cd ${./.} && shellcheck commands/*; touch $out";
        };

        devShells.default = pkgs.devshell.mkShell {
          imports = [ "${inputs.devshell}/extra/git/hooks.nix" ];
          name = "xilinx-dev-shell";
          packages = [
            pkgs.coreutils
            pkgs.glow
            pkgs.python3
            pkgs.unzip
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
                exec ${./.}/commands/${command} "''${@}"
              '';
              commands = {
                create-project = "creates a new project based on a template";
                store = "create a restore script for a given project";
                restore = "restore a project using a generated restore script";
                build-hw-config = "generate a hw config for given platform";
                build-bootloader = "build the bootloader for a script";
                jtag-boot = "deploy a firmware via jtag";
                launc-picocom = "launc the picocom serial monitor";
              };
            in
            [
              {
                name = "show-readme";
                command = ''glow "$PRJ_ROOT/README.md"'';
                help = "";
              }
            ] ++ (pkgs.lib.mapAttrsToList
              (name: help: {
                inherit name help;
                command = commandTemplate name;
              })
              commands);
        };

        # just add every package as a hydra job
        hydraJobs = packages;
      }
    );
}
