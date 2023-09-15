# Script Documentation for Bootloader Updates over Ethernet
The intention of this bootscript is to use a running U-Boot instance to update the bootloader via tftp.
This bootscript is used if updates are implemented in either the FSBL, the FPGA configuration (PS, PL) or the U-Boot configuration. This script enables a full bootloader update without the need of disassembling the FCC or any JTAG connection.  
The bootscript takes the new bootloader image (FSBL + FPGA bitstream + U-Boot) and stores it in the processor flash memory.  
The actual updates/changes in the confgurations have to be performed/implemented in the [hap-fpga-images](https://gitlab.dlr.de/hap/hardware-projects/hap-fpga-images) repository.  
To build the updated bootloader modules, please refer to this [guide](https://gitlab.dlr.de/hap/hardware-projects/hap-fpga-images/-/blob/master/HW_Config_Deployment.md). Follow the instructions until the bootable image (lab-setup.BOOT.bin) is builded using the `generateBootImage.py` script.  
When the udpated boot image is generated, switch to the [deployment](https://gitlab.dlr.de/hap/deployment) repository and call the `hap-ctrl.py` script.  
Use the following command to update the bootloader on the targets hardware:  
```
./common/utils/hap-ctrl.py [--dev] [--monitoring] bootloaderUpdate <path/lab-setup.BOOT.bin>
```  
The `--dev` option has to be used to update the bootloader on a development board. Otherwise the FCC will be udpated. The `--monitoring` option indicates that the image is configured for the monitoring lane.  
The `hap-ctrl.py` script will activate the bootloaderUpdate bootscript to be executed by the U-Boot instance running the the processor. If a development board is used, the developer has to perform a manual power cycle. U-Boot will then download the `lab-setup.BOOT.bin` image in the processor flash.  
When the flash operation succeeded a power cycle has to be triggered again.  
**WARNING: You have to abort the boot process this time. Otherwise the bootloader update will be repeated.**  
Then follow the steps printed in the console and make the final configuration steps for the new U-Boot instance (server IP, MAC address, flags).  
Then use the `hap-ctrl.py` script again to setup the software to be executed on the processor.  
To complete the process, trigger a power cycle again.  
Now the processor should boot the specified software with the new bootloader image and FPGA configuration.  
If anything went wrong during this process, it is likely that an image update via JTAG is required. If so, refer to this [guide](https://gitlab.dlr.de/hap/hardware-projects/hap-fpga-images/-/blob/master/HW_Config_Deployment.md).  
