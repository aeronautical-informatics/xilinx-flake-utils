{
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
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
        # pkgs.symlinkJoin { name = "${nameLowercase}-${edition}"; paths = [ toolchain-raw fhs ]; };
      in
      {
        packages = builtins.listToAttrs
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
      }
    );
}
