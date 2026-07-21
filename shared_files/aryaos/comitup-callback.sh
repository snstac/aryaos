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

# Move wlan0 between firewalld zones based on comitup state. While it is the
# onboarding access point (HOTSPOT), pin it to the tight "aryaos-hotspot" zone so
# a walk-up client can reach only DHCP/DNS/portal/web-admin — not ssh, Node-RED,
# or the mesh feed. Once wlan0 becomes a trusted client uplink (CONNECTED),
# restore the normal default zone so the operator is not locked out.
WIFI_DEV="wlan0"
case "${1:-}" in
	HOTSPOT)
		firewall-cmd --zone=aryaos-hotspot --change-interface="${WIFI_DEV}" >/dev/null 2>&1 || true
		;;
	CONNECTED)
		firewall-cmd --zone=public --change-interface="${WIFI_DEV}" >/dev/null 2>&1 || true
		;;
esac

# Ping a callback on Node-RED:
wget -a http://127.0.0.1:1880/comitup_callback/$*
