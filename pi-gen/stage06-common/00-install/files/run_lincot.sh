#!/bin/bash
# AryaOS run_lincot.sh
#
# Startup file for lincot.
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
  # shellcheck source=../../../stage3-base/00-install/files/aryaos-config.txt
  . $AOS_CONFIG
else
  echo "$AOS_CONFIG doesn't exist, exiting."
  exit 1
fi

lincot_CONF="/etc/lincot-config.txt"

if [ -f $lincot_CONF ]; then
  # shellcheck source=lincot-config.txt
  . $lincot_CONF
else 
  echo "$lincot_CONF doesn't exist, initializing."
  echo 'CALLSIGN=""' >> $lincot_CONF
fi

if ! grep -qs -e 'CALLSIGN' $lincot_CONF; then
  echo "Adding empty CALLSIGN to $lincot_CONF"
  echo 'CALLSIGN=""' >> $lincot_CONF
fi

if [ -z "$NODE_ID" ]; then
  echo "NODE_ID not set, will retry..."
  exit 1
fi

if [ -z "$CALLSIGN" ]; then
  echo "CALLSIGN not set"
  NEW_CALLSIGN="${AOS_FLAVOR:-AryaOS}-${NODE_ID: -4}"
  
  ## TEMP File
  TFILE=$(mktemp --tmpdir tfile.XXXXX)
  ## trap Deletes TFILE on Exit
  trap 'rm -f "$TFILE"' 0 1 2 3 15

  sed --follow-symlinks -i -E -e "s/CALLSIGN.*/CALLSIGN=$NEW_CALLSIGN/" > "$TFILE"
  cat "$TFILE" > $lincot_CONF
  logger "AryaOS lincot callsign is now set to: $NEW_CALLSIGN"
  export CALLSIGN=$NEW_CALLSIGN
fi

set +a

/usr/local/bin/lincot
