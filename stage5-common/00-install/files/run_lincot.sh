#!/bin/bash
# AryaOS run_LINCOT.sh
#
# Startup file for LINCOT.
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
AOS_CONFIG="/boot/${AOS_FLAVOR:-AryaOS}-config.txt"

if [ -f $AOS_CONFIG ]; then
  . $AOS_CONFIG
else
  echo "$AOS_CONFIG doesn't exist, exiting."
  exit 1
fi

LINCOT_CONF="/boot/LINCOT-config.txt"

if [ -f $LINCOT_CONF ]; then
  . $LINCOT_CONF
else 
  echo "$LINCOT_CONF doesn't exist, initializing."
  echo 'CALLSIGN=""' >> $LINCOT_CONF
fi

if ! grep -qs -e 'CALLSIGN' $LINCOT_CONF; then
  echo "Adding empty CALLSIGN to $LINCOT_CONF"
  echo 'CALLSIGN=""' >> $LINCOT_CONF
fi

if [ -z "$NODE_ID" ]; then
  echo "NODE_ID not set, will retry..."
  exit 1
fi

if [ -z "$CALLSIGN" ]; then
  echo "CALLSIGN not set"
  NEW_CALLSIGN="${AOS_FLAVOR:-AryaOS}-${NODE_ID: -4}"
  sed --follow-symlinks -i -E -e "s/CALLSIGN.*/CALLSIGN=$NEW_CALLSIGN/" $LINCOT_CONF
  logger "AryaOS LINCOT callsign is now set to: $NEW_CALLSIGN"
  export CALLSIGN=$NEW_CALLSIGN
fi

set +a

/usr/local/bin/lincot
