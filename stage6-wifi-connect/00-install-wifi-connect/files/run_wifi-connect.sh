#!/bin/bash -e

# WIFI_MAC=$(ip link show wlan0|awk '/ether/ {print $2}'|awk -F: '{print $5$6}')
NODEID=$(python3 -c "import uuid;nn=str(uuid.getnode());print(nn[len(nn)-4:len(nn)])")
WIFI_SSID="AirTAK-${NODEID}"

iwgetid -r

if [ $? -eq 0 ]; then
    printf "Skipping WiFi Connect, connected to SSID: $(iwgetid -r)\n"
    exit 0
else
    printf "Starting WiFi Connect as SSID: ${WIFI_SSID}\n"
    wifi-connect -o 9080 -s ${WIFI_SSID}
fi
