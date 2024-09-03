#!/bin/bash

cd /root/
sleep 1

#setup wlan adapters and put them in monitor mode
wlan1new=`cat dronescout.conf | sed '/^#/d' | grep WLAN_USB_1 | sed 's/;.*//g' | sed 's/ //g' | sed 's/WLAN_USB_1=//g'`
wlan_adapter=$wlan1new
ip link set $wlan_adapter down
iw $wlan_adapter set monitor control
ip link set $wlan_adapter up
iw dev $wlan_adapter set channel 1

wlan2new=`cat dronescout.conf | sed '/^#/d' | grep WLAN_USB_2 | sed 's/;.*//g' | sed 's/ //g' | sed 's/WLAN_USB_2=//g'`
wlan_adapter=$wlan2new
ip link set $wlan_adapter down
iw $wlan_adapter set monitor control
ip link set $wlan_adapter up
iw dev $wlan_adapter set channel 1

#for ds240 only
wlan3new=`cat dronescout.conf | sed '/^#/d' | grep WLAN_USB_3 | sed 's/;.*//g' | sed 's/ //g' | sed 's/WLAN_USB_3=//g'`
if [[ -n "$wlan3new" ]]; then
        wlan_adapter=$wlan3new
        ip link set $wlan_adapter down
        iw $wlan_adapter set monitor control
        ip link set $wlan_adapter up
        iw dev $wlan_adapter set channel 1
fi


TERM=vt100 screen -dmS WATCHDOG /root/watchdog.sh

sleep 1
cd /root/
PATH_MAPPING="/sys/firmware/devicetree/base/serial-number:/config/serial-number" LD_PRELOAD=/config/path-mapping-quiet.so ./dronescout

exit 0