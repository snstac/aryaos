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

# shellcheck source=aryaos-device-suffix.sh
. /usr/local/sbin/aryaos-device-suffix.sh

AOS_CONFIG="/etc/aryaos/aryaos-config.txt"

if [[ -f $AOS_CONFIG ]]; then
	# shellcheck source=aryaos-config.txt
	. "$AOS_CONFIG"
fi

COMITUP_CONF="/etc/comitup.conf"
COMITUP_DNS_DIR="/usr/share/comitup/dns"

# Bluetooth PAN and the Wi-Fi onboarding hotspot each run a dnsmasq DHCP
# server. Both must bind their DHCP socket to exactly one interface or the
# first process to claim UDP/67 prevents the other from starting. Comitup may
# launch dnsmasq before wlan0 exists, so bind-dynamic is required here rather
# than bind-interfaces. Reconcile this on every start because these files are
# owned by the upstream comitup package and can be replaced by an apt upgrade.
for dns_conf in \
	"${COMITUP_DNS_DIR}/dns-hotspot.conf" \
	"${COMITUP_DNS_DIR}/dns-connected.conf"; do
	[[ -f "${dns_conf}" ]] || continue
	if ! grep -qxF 'bind-dynamic' "${dns_conf}"; then
		sed --follow-symlinks -i '/^bind-interfaces$/d' "${dns_conf}"
		printf '\nbind-dynamic\n' >> "${dns_conf}"
	fi
done

if [[ ! -f ${COMITUP_CONF} ]]; then
	echo "${COMITUP_CONF} doesn't exist, initializing."
	echo "# ap_name:" >>"${COMITUP_CONF}"
fi

if ! grep -qs -e 'ap_name' "${COMITUP_CONF}"; then
	echo "Adding empty ap_name to ${COMITUP_CONF}"
	echo "# ap_name:" >>"${COMITUP_CONF}"
fi

if [[ -z "${WIFI_SSID:-}" ]]; then
	if [[ -z "${DEVICE_SUFFIX:-}" ]]; then
		DEVICE_SUFFIX="$(device_suffix)" || true
	fi
	if [[ -z "${DEVICE_SUFFIX:-}" ]]; then
		echo "DEVICE_SUFFIX not set, will retry..."
		exit 1
	fi
	WIFI_SSID="${AOS_FLAVOR:-AryaOS}-${DEVICE_SUFFIX}"
	logger "AryaOS comitup generated new WIFI_SSID: $WIFI_SSID"
fi

# Set ap_name to the current SSID on every start so it tracks the device suffix
# even after it has already been set once — e.g. a factory reset regenerates
# DEVICE_SUFFIX, and the hotspot must follow the new aryaos-xxxx identity. Rewrite
# an active "ap_name:" line if present, otherwise uncomment the "# ap_name:"
# template. (The old sed only matched the commented form, so the SSID went stale
# and kept broadcasting the previous suffix after an identity change.)
if grep -qsE '^ap_name:' "${COMITUP_CONF}"; then
	sed --follow-symlinks -i -E -e "s/^ap_name:.*/ap_name: ${WIFI_SSID}/" "${COMITUP_CONF}"
else
	sed --follow-symlinks -i -E -e "s/^#[[:space:]]*ap_name:.*/ap_name: ${WIFI_SSID}/" "${COMITUP_CONF}"
fi

logger "AryaOS comitup using SSID: $WIFI_SSID"

/usr/sbin/comitup
