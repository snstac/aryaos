#!/bin/bash -e
# aryaos-firstboot.sh — first-boot DEVICE_SUFFIX and hostname aryaos-xxxx.
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

set -a

AOS_CONFIG="/etc/aryaos/aryaos-config.txt"
CHANGED=0

if [[ -f $AOS_CONFIG ]]; then
	# shellcheck source=aryaos-config.txt
	. "$AOS_CONFIG"
else
	echo "$AOS_CONFIG doesn't exist, initializing."
	install -d -m 0755 /etc/aryaos
	touch "$AOS_CONFIG"
	echo 'DEVICE_SUFFIX=""' >>"$AOS_CONFIG"
fi

grep -qs -e 'DEVICE_SUFFIX' "$AOS_CONFIG" || echo 'DEVICE_SUFFIX=""' >>"$AOS_CONFIG"

# DEVICE_SUFFIX — last 4 of machine-id (or MAC) for hostname and WiFi SSID.
if [[ -z "${DEVICE_SUFFIX}" ]]; then
	NEW_SUFFIX="$(device_suffix)" || {
		echo "device_suffix: could not derive suffix" >&2
		exit 1
	}
	sed --follow-symlinks -i -E -e "s/^DEVICE_SUFFIX=.*/DEVICE_SUFFIX=${NEW_SUFFIX}/" "$AOS_CONFIG"
	echo "AryaOS DEVICE_SUFFIX is now set to: $NEW_SUFFIX"
	DEVICE_SUFFIX="$NEW_SUFFIX"
	CHANGED=1
fi

# Hostname — factory image uses "aryaos"; personalize once to aryaos-xxxx.
CURRENT_HOST="$(hostnamectl hostname 2>/dev/null || hostname -s)"
if [[ "$CURRENT_HOST" == aryaos && -n "${DEVICE_SUFFIX}" ]]; then
	NEW_HOST="aryaos-${DEVICE_SUFFIX}"
	hostnamectl set-hostname "$NEW_HOST"
	if grep -qE '^127\.0\.1\.1[[:space:]]+aryaos([[:space:]]|$)' /etc/hosts; then
		sed -i -E "s/^127\.0\.1\.1[[:space:]]+aryaos/127.0.0.1 ${NEW_HOST}/" /etc/hosts
	fi
	if grep -qE '^::1[[:space:]]+aryaos([[:space:]]|$)' /etc/hosts; then
		sed -i -E "s/^::1[[:space:]]+aryaos/::1 ${NEW_HOST}/" /etc/hosts
	fi
	systemctl try-restart avahi-daemon.service 2>/dev/null || true
	echo "AryaOS hostname is now: $NEW_HOST"
	CHANGED=1
fi

if getent group node-red >/dev/null 2>&1 && [[ -d /etc/aryaos ]]; then
	chown -R node-red /etc/aryaos
fi

if [[ "$CHANGED" -eq 0 ]]; then
	exit 64
fi
