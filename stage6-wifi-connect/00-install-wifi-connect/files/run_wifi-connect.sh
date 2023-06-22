#!/bin/bash -e
# Startup file for WiFi Connect
#
# Copyright 2023 Sensors & Signals LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


AIRTAK_CONF="/boot/airtak-config.txt"
WIFI_CONNECT_CONF="/boot/wifi-connect-config.txt"

if [[ -f ${AIRTAK_CONF} ]]; then
  . ${AIRTAK_CONF}
fi

if [[ -f ${WIFI_CONNECT_CONF} ]]; then
  . ${WIFI_CONNECT_CONF}
else 
  echo "${WIFI_CONNECT_CONF} doesn't exist, initializing."
  echo 'SSID=""' >> ${WIFI_CONNECT_CONF}
fi

if ! grep -qs -e 'SSID' ${WIFI_CONNECT_CONF}; then
  echo "Adding empty SSID to ${WIFI_CONNECT_CONF}"
  echo 'SSID=""' >> ${WIFI_CONNECT_CONF}
fi

if [ -z "$NODE_ID" ]; then
  echo "NODE_ID not set, will retry..."
  exit 1
fi

if [ -z "$SSID" ]; then
  echo "SSID not set"
  NEW_SSID="AirTAK-${NODE_ID: -4}"
  sed --follow-symlinks -i -E -e "s/SSID.*/SSID=$NEW_SSID/" ${WIFI_CONNECT_CONF}
  echo "SSID is now set to: $NEW_SSID"
  export SSID=$NEW_SSID
fi

if iwgetid -r; then
    printf "Skipping WiFi Connect, connected to SSID: $(iwgetid -r)\n"
    exit 0
else
    printf "Starting WiFi Connect as SSID: ${SSID}\n"
    wifi-connect -o 9080 -s ${SSID}
fi
