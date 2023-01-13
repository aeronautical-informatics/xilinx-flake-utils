# Troubleshooting

## JTAG connection fails

If JTAG access fails, make sure that you have an
[udev](https://www.freedesktop.org/software/systemd/man/udev.html) rule in
place that tags the JTAG device with `uaccess`. All devices with this tag are
configured so that all local users can access them. You can either install
a driver from Xilinx (which actually is just some udev rules, since the real
driver --- `ftdi_sio` --- is part of the linux kernel), or you can manually
place the rule. It is important that your rule is lexically before `73-seat-
late.rules`, otherwise setting the `TAG+="uaccess"` does not have any effect.
You can quite easily formulate the rule yourself: use `lsusb` to find the
vendor id and product id of the JTAG probe.

```
$ lsusb
# ...
Bus 004 Device 009: ID 0403:6010 Future Technology Devices International, Ltd FT2232C/D/H Dual UART/FIFO IC
# ...
```

In this example, the FTDI device has the vendor id `0403` and the product id
`6010`. Now, the udev rule only has to be formulated to tag any device matching
this combination of vendor and product id with the `uaccess` flag:

```
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", TAG+="uaccess"
```

Save that rule to a file that is executed before `73-seat-late.rules`, e.g.
`61-xilinx-jtag-probe.rules` in `/etc/udev/rules.d`. This rule tags the device,
and once `73-seat-late.rules` is executed all tagged devices are configured so
that normal, local users (thus the `seat` in `73-seat-late.rules`) can access
the device.