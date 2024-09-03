#!/bin/bash -e
# comitup-callback.sh Callback for comitup state changes
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

# FIXME: https://github.com/snstac/aryaos/issues/48
logger "AryaOS comitup callback: $*"

# Ping a callback on Node-RED:
wget -a http://127.0.0.1:1880/comitup_callback/$*
