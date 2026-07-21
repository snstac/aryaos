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
#
# The zone MUST be set via the NetworkManager connection, not a runtime
# `firewall-cmd --change-interface`: NM owns an managed interface's zone through
# the connection's `connection.zone` property and reverts any manual runtime
# binding on the next connection event (which left wlan0 in the default `public`
# zone despite this callback firing). `nmcli device reapply` applies the change
# without dropping the AP.
WIFI_DEV="wlan0"
set_wlan_zone() {
	local zone="$1" conn
	conn="$(nmcli -t -f GENERAL.CONNECTION device show "${WIFI_DEV}" 2>/dev/null | sed 's/^GENERAL.CONNECTION://')"
	[ -n "${conn}" ] || return 0
	nmcli connection modify "${conn}" connection.zone "${zone}" >/dev/null 2>&1 || true
	nmcli device reapply "${WIFI_DEV}" >/dev/null 2>&1 \
		|| firewall-cmd --zone="${zone:-public}" --change-interface="${WIFI_DEV}" >/dev/null 2>&1 || true
}
case "${1:-}" in
	HOTSPOT)
		set_wlan_zone aryaos-hotspot
		;;
	CONNECTED)
		# Empty zone => the connection uses the default (public) zone.
		set_wlan_zone ""
		;;
esac

# Ping a callback on Node-RED:
wget -a http://127.0.0.1:1880/comitup_callback/$*
