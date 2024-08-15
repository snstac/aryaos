#!/bin/bash
# AryaOS run_readsb.sh
#
# Startup file for readsb.
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
READSB_CONFIG="/etc/default/readsb"

if [ -f $AOS_CONFIG ]; then
  . $AOS_CONFIG
fi

if [ -f $READSB_CONFIG ]; then
  . $READSB_CONFIG
fi

set +a

/usr/bin/readsb \
 $RECEIVER_OPTIONS $DECODER_OPTIONS $NET_OPTIONS $JSON_OPTIONS \
 --write-json $ADSB_JSON --quiet