# Script Documentation for U-Boot Updates over Ethernet
The intention of this bootscript is to use a running U-Boot instance to download a new version image via tftp.
If something goes wrong during this update it is likely required to reprogram the flash over JTAG using the tools provided by [hap-fpga-images](https://gitlab.dlr.de/hap/hardware-projects/hap-fpga-images/-/tree/master/utils/bootloader).

Also keep in mind that resetting the board will reapply the update every time!
It is best to use `hap-ctrl.py` after the update was successful to update the served bootscript.

## Documentation
Display User Info and define the RAM address to load to.
`ub_size` is the section size to erase. It is derived from Xilinx program_flash tool.
`img_dir` holds the location of the U-Boot image to upgrade to. It should be a file created by `generateBootImage.py` of [hap-fpga-images](https://gitlab.dlr.de/hap/hardware-projects/hap-fpga-images/-/tree/master/utils/bootloader).

```
echo =================================
echo ======== Update U-Boot ==========
echo =================================

echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo !! Do not disconnect board while updating !!
echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

echo ------- settings -------
setenv tmp_addr 0x08000000
setenv ub_size 3E0000
setenv img_dir /srv/tftp/hap/uboot.img

```

Try to download the image and reset the board if something goes wrong.
```
echo ------- Download U-Boot image ------
if tftpboot ${tmp_addr} ${img_dir}; then
    echo Download Successful
    setenv img_size ${filesize};
else
    echo !! Warning. Download Failed. Aborting Update !!;
    sleep 30;
    reset;
fi;


echo ------- Init Flash -------
sf probe

```

Erase the flash section U-Boot is stored in. It is derived from Xilinx program_flash tool.
```
echo ------- Erase Flash -------
sf erase 0x0 ${ub_size}
```

Perform a blank check by setting a correctly sized memory region to `ffffffff` and compare it to another region loaded from the erased flash.
```
echo ------- Blank Check -------
mw 0x0F800000 ffffffff ${ub_size}
sf read 0x0F000000 0x0 ${ub_size}
cmp.b 0x0F000000 0x0F800000 ${ub_size}
```

Write the downloaded image to the previously erased location. It is important to do something between sf erase and sf write, otherwise writing fails.
```
echo ------- Write U-Boot to Flash ------
sf write ${tmp_addr} 0x0 ${img_size}
```

Compare the image written in flash with the downloaded one.
```
echo ------- Check written Data ------
sf read 0x0F000000 0x0 ${img_size}
cmp.b 0x0F000000 ${tmp_addr} ${img_size}
```

After updating is done inform the user how to proceed.
```
echo ------- Updating U-Boot Done ------
echo Resetting now will restart the update process again. Abort the upcoming autoboot to stop.
echo This instance of U-Boot continues to run but it is the old version.
echo Please reset, then load default environment variables and set serverip and ethernet/MAC address and reset again to complete the update.
echo See ubootUpdate.md for help.
```

The instructions are the same as when performing a regular [programFlash](https://gitlab.dlr.de/hap/hardware-projects/hap-fpga-images/-/blob/master/utils/bootloader/programFlash.py#L197). Type into board console:
- `reset`/ powercycle the board
- stop the upcoming autoboot
- reset environment variables using `env default -f -a`
- set the serverip variable using `setenv serverip <your-server-ip-address>`
- set the ethernet/MAC address for the corresponding lane:
    - commanding: `setenv ethaddr 02:fc:c0:0a:11:ce`
    - monitoring: `setenv ethaddr 02:fc:c0:0c:a1:eb`
- save the new environment variables `saveenv`
