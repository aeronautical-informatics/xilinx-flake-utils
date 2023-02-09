
# Author: Phillip Noeldeke, German Aerospace Center (DLR) 2022


## set workspace
setws ../hardware/zedboard/vitis_tmp

## clean the modified project
app clean fsbl_modified_zedboard

## Regenerate the platform
platform active zedboard_platform
platform generate

## Rebuild the modified project
app build fsbl_modified_zedboard
