# Getting started

First, checkout the outputs provided by this flake: `nix flake show`. It
contains builds for both __Vitis__ and __Vivado__. Note that typically the
__Vitis__ package include a version of vivado, so choose __Vitis__ if you want
both.

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
restore zynq_7000_basic target
generate-hw-config target/workspace target/hw
build-bootloader vitis_platform_zynq7000.tcl target/hw/hw_export.xsa target/bootloader
jtag-boot zynq7000_init.tcl target app.elf
```
