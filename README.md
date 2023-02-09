# Getting started

First, checkout the outputs provided by this flake: `nix flake show`. It
contains builds for both __Vitis__ and __Vivado__. Note that typically the
__Vitis__ package include a version of vivado, so choose __Vitis__ if you want
both.

__Note__: If you experience an issue, pay the
 [troubleshooting section](docs/TROUBLESHOOTING.md) a visit!

# Example usage

__Note__: this presumes that your current environment contains various
software. One way of entering an environment that fulfills this requirement
would be to enter a nix development shell via `nix develop`.

Typically, you start of by creating a project (using `restore`). This if
followed by the generation of the hardware description `generate-hw-config` for
that project. You can then compile a bootloader using the `build-bootloader`
command. Finally, provided that you also have a final application image in the
form of an ELF file, you can deploy the image via JTAG to a running SoC using
the `jtag-boot` command.

```console
create-project zynq7000 target zynq7000_example
generate-hw-config target/zynq7000_example
build-bootloader vitis_platform_zynq7000.tcl target/zynq7000_example
build-bootloader zynq7000 target/zynq7000_example
jtag-boot zynq7000_init.tcl target app.elf
```

