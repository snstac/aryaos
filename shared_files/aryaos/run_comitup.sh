#!/bin/bash -e
# run_comitup.sh Startup file for comitup
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at 
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

AOS_CONFIG="/etc/aryaos/aryaos-config.txt"

if [ -f $AOS_CONFIG ]; then
  # shellcheck source=aryaos-config.txt
  . $AOS_CONFIG
fi

COMITUP_CONF="/etc/comitup.conf"

if [ ! -f ${COMITUP_CONF} ]; then
  echo "${COMITUP_CONF} doesn't exist, initializing."
  echo "# ap_name:" >> "${COMITUP_CONF}"
fi

if ! grep -qs -e 'ap_name' ${COMITUP_CONF}; then
  echo "Adding empty ap_name to ${COMITUP_CONF}"
  echo "# ap_name:" >> "${COMITUP_CONF}"
fi

if [ -z "$WIFI_SSID" ]; then
  if [ -z "$NODE_ID" ]; then
    echo "NODE_ID not set, will retry..."
    exit 1
  fi
  WIFI_SSID="${AOS_FLAVOR:-AryaOS}-${NODE_ID: -4}"
  logger "AryaOS comitup generated new WIFI_SSID: $WIFI_SSID"
fi

sed --follow-symlinks -i -E -e "s/# ap_name:.*/ap_name: $WIFI_SSID/" "${COMITUP_CONF}"

logger "AryaOS comitup using SSID: $WIFI_SSID"

/usr/sbin/comitup
