#!/bin/sh
https://discourse.nixos.org/t/looking-for-help-to-create-a-raspberry-pi-with-usb-ethernet/27039/9

set -x

mkdir -p /sys/kernel/config/usb_gadget/pi4
cd /sys/kernel/config/usb_gadget/pi4
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass
echo 0x01 > bDeviceProtocol
mkdir -p /sys/kernel/config/usb_gadget/pi4/strings/0x409
echo "fedcba9876543211" > strings/0x409/serialnumber
echo "TheWifiNinja" > strings/0x409/manufacturer
echo "PI4 USB Device" > strings/0x409/product
mkdir -p /sys/kernel/config/usb_gadget/pi4/configs/c.1/strings/0x409
echo "Config 1: ECM network" > configs/c.1/strings/0x409/configuration
echo 250 > configs/c.1/MaxPower
# Add functions here
# see gadget configurations below
# End functions
mkdir -p /sys/kernel/config/usb_gadget/pi4/functions/ecm.usb0
HOST="00:dc:c8:f7:75:14" # "HostPC"
SELF="00:dd:dc:eb:6d:a1" # "BadUSB"
echo $HOST > functions/ecm.usb0/host_addr
echo $SELF > functions/ecm.usb0/dev_addr
ln -s functions/ecm.usb0 configs/c.1/

udevadm settle -t 5 || :
ls /sys/class/udc > UDC