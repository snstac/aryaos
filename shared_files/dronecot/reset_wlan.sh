#!/bin/bash
# reset_wlan.sh Reset WLAN interfaces.
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

set -a

AOS_CONFIG="/etc/aryaos/aryaos-config.txt"

if [ -f $AOS_CONFIG ]; then
  # shellcheck source=aryaos-config.txt
  . $AOS_CONFIG
fi


set +a

modprobe -r rtw88_8821cu || true
modprobe rtw88_8821cu rtw_power_mgnt=0 rtw_ips_mode=0 rtw_enusbss=0 || true
nmcli dev set wlan0 managed no || true
nmcli dev set wlan1 managed no || true
nmcli dev set wlan2 managed no || true
nmcli dev set wlan3 managed no || true
