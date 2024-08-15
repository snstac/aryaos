#!/bin/bash -e
# AryaOS get_position.sh
#
# Get the static position of the system (bypass gps).
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

# FIXME: I don't like this and neither should you.
echo "{\"class\": \"TPV\", \"lat\": $STATIC_LAT, \"lon\": $STATIC_LON, \"altHAE\": $STATIC_ALT, \"track\": \"9999999.0\", \"speed\": \"9999999.0\"}"
