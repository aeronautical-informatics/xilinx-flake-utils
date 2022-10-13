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
        build-xilinx-toolchain = { name ? "Vivado", src, edition, products, version }:
          let
            nameLowercase = pkgs.lib.toLower name;
            fhsName = nameLowercase + "-fhs";
            toolchain-raw = pkgs.stdenv.mkDerivation rec {
              inherit src version;
              pname = nameLowercase + "-raw";
              nativeBuildInputs = with pkgs; [ pigz xorg.xorgserver (genFhs { }) ];
              unpackCmd = "tar -I pigz -xf $curSrc";
              dontFixup = true;

              installPhase = ''
                runHook preInstall

                substitute ${./assets/install_config.txt} install_config.txt \
                  --subst-var out \
                  --subst-var-by products '${genProductList products}' \
                  --subst-var-by edition '${edition}'

                export DISPLAY=:1
                Xvfb $DISPLAY &
                xvfb_pid=$!
                xilinx-fhs xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms --batch Install --config install_config.txt
                kill $xvfb_pid

                runHook postInstall
              '';
            };
            fhs = genFhs {
              name = fhsName;
              profile = ''
                export LC_NUMERIC="en_US.UTF-8"
                source ${toolchain-raw}/${name}/*/settings64.sh
              '';
            };
          in
          pkgs.symlinkJoin { name = "${nameLowercase}-${edition}"; paths = [ toolchain-raw fhs ]; };
      in
      {
        packages = builtins.listToAttrs (pkgs.lib.flatten (pkgs.lib.mapAttrsToList
          (version: { editions, products, sha256 }: builtins.map
            (edition: pkgs.lib.nameValuePair
              (pkgs.lib.toLower (
                builtins.replaceStrings [ " " "." ] [ "-" "-" ] "${edition}-${version}"
              ))
              (build-xilinx-toolchain {
                name = "Vivado";
                src = pkgs.requireFile {
                  name = "Xilinx_Vivado_${version}.tar.gz";
                  url = "https://www.xilinx.com/";
                  inherit sha256;
                };
                inherit edition products version;
              }))
            editions)
          versions));
      }
    );
}
