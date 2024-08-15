#!/bin/bash -e
# AryaOS set_uuid.sh
# Sets a reliable network identification for this device over using 
# either the firmware serial number (Raspberry Pi 4, 5) or an RFC 4122 UUID.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
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

set -a

AOS_CONFIG="/etc/aryaos-config.txt"

if [ -f $AOS_CONFIG ]; then
  # shellcheck source=aryaos-config.txt
  . $AOS_CONFIG
else
  echo "$AOS_CONFIG doesn't exist, initializing."
  echo 'NODE_ID=""' >> $AOS_CONFIG
fi


# Doesn't work:
#   if grep -qs -e 'NODE_ID' $AOS_CONFIG; then
grep -qs -e 'NODE_ID' $AOS_CONFIG
retVal=$?
if [ $retVal  -ne 0 ]; then
  echo "Adding empty NODE_ID to $AOS_CONFIG"
  echo 'NODE_ID=""' >> $AOS_CONFIG
fi

if [ -z "${NODE_ID}" ]; then
  if [ -f /sys/firmware/devicetree/base/serial-number ]; then
    echo "Using serial number to generate NODE_ID."
    # Remove Null at end of serial number.
    NEW_NODE_ID="$(tr -d '\000' < /sys/firmware/devicetree/base/serial-number)"
  else
    echo "Using UUID to generate NODE_ID."
    NEW_NODE_ID="$(python3 -c "import uuid;print(str(uuid.uuid4()).upper())")"
  fi
  sed --follow-symlinks -i -E -e "s/NODE_ID.*/NODE_ID=$NEW_NODE_ID/" $AOS_CONFIG
  echo "AryaOS NODE_ID is now set to: $NEW_NODE_ID"
else
  exit 64
fi