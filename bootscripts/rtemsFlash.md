# This file provides comments and explanation for the rtemsFlash bootscript
There is no need to check for networking as this script can only be executed if it was loaded via tftp.
```
echo ===============================
echo ======== RTEMS Flash ==========
echo ===============================
echo ------- settings -------
```
Define an executable environment variable `boot_image` that loads the software image from flash into RAM and executes it. Keep in mind that flash needs to be initialized beforehand.
```
setenv boot_image 'sf read ${loadaddr} ${flash_img} ${img_size}; bootm ${loadaddr}'
```
Define addresses to use for data allocation. `tmp_addr` is a RAM address that is usually considered safe by u-boot docs. `flash_img` lies some megabytes behind the u-boot environment section.
```
setenv tmp_addr 0x08000000
setenv flash_img 0x700000
```
Set the tftp path of the software image depending on the lane either commanding or monitoring images are created and respective bootscripts used.
```
setenv img_dir /srv/tftp/hap/hap.<lane>.img


echo ------- Init Flash -------
sf probe

echo ------- Download software image ------
tftpboot ${tmp_addr} ${img_dir}
```
Store the filesize to be able to read from flash after reboot. (Reading requires the amount of bytes to read)
```
setenv img_size ${filesize}
```
Write the downloaded image to flash.
```
echo ------- Write image to flash ------
sf erase ${flash_img} +${img_size}
sf write ${tmp_addr} ${flash_img} ${img_size}
```
Save environment variables.
```
saveenv 

echo ------- Boot from Flash ------
run boot_image

``` 
