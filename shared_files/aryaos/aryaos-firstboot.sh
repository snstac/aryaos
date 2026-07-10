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

grep -qs -e 'COT_HOST_ID' "$AOS_CONFIG" || echo 'COT_HOST_ID=""' >>"$AOS_CONFIG"

# COT_HOST_ID — functional source id stamped into CoT _flow-tags_/remarks by the
# PyTAK tools. Defaults to aryaos-<suffix> (matches the hostname).
if [[ -z "${COT_HOST_ID}" && -n "${DEVICE_SUFFIX}" ]]; then
	NEW_HOST_ID="aryaos-${DEVICE_SUFFIX}"
	sed --follow-symlinks -i -E -e "s/^COT_HOST_ID=.*/COT_HOST_ID=${NEW_HOST_ID}/" "$AOS_CONFIG"
	echo "AryaOS COT_HOST_ID is now set to: $NEW_HOST_ID"
	COT_HOST_ID="$NEW_HOST_ID"
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

# Node-RED flows may edit the site config file, but must NOT own /etc/aryaos
# itself (a recursive chown here used to hand the Node-RED user the TAK TLS
# client key under /etc/aryaos/tls — an editor compromise became key theft).
if getent group node-red >/dev/null 2>&1 && [[ -f "$AOS_CONFIG" ]]; then
	chown node-red "$AOS_CONFIG" 2>/dev/null || true
fi
if [[ -d /etc/aryaos ]]; then
	chown root:root /etc/aryaos
	chmod 0755 /etc/aryaos
fi

# Site-wide TAK TLS: gateways read /etc/aryaos/tls/client.key via the tak-certs
# group (installed from the "AryaOS Site" Cockpit plugin). Service users are
# created by their debs, so membership is reconciled here on every boot.
getent group tak-certs >/dev/null 2>&1 || groupadd --system tak-certs
for svc_user in adsbcot aiscot dronecot lincot charontak; do
	if getent passwd "$svc_user" >/dev/null 2>&1; then
		usermod -aG tak-certs "$svc_user" 2>/dev/null || true
	fi
done
if [[ -d /etc/aryaos/tls ]]; then
	chown -R root:tak-certs /etc/aryaos/tls 2>/dev/null || true
	chmod 0750 /etc/aryaos/tls 2>/dev/null || true
	[[ -f /etc/aryaos/tls/client.key ]] && chmod 0640 /etc/aryaos/tls/client.key 2>/dev/null || true
fi

# Every published image shares the build-time snakeoil TLS key pair. Mint a
# per-device key/cert for the web portal + Cockpit HTTPS proxy on first boot
# (after the hostname is personalized, so the CN matches aryaos-xxxx).
TLS_REGEN_MARKER="/etc/aryaos/.web-tls-regenerated"
if [[ ! -f "$TLS_REGEN_MARKER" ]] && command -v make-ssl-cert >/dev/null 2>&1; then
	if make-ssl-cert generate-default-snakeoil --force-overwrite; then
		(
			umask 077
			install -d -m 0755 /etc/lighttpd/ssl
			cat /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/private/ssl-cert-snakeoil.key \
				>/etc/lighttpd/ssl/snakeoil-combined.pem.tmp
			mv -f /etc/lighttpd/ssl/snakeoil-combined.pem.tmp /etc/lighttpd/ssl/snakeoil-combined.pem
		)
		chmod 0640 /etc/lighttpd/ssl/snakeoil-combined.pem
		chgrp ssl-cert /etc/lighttpd/ssl/snakeoil-combined.pem 2>/dev/null || true
		systemctl try-restart lighttpd.service 2>/dev/null || true
		touch "$TLS_REGEN_MARKER"
		echo "Per-device web TLS certificate generated."
		CHANGED=1
	fi
fi

# Images ship with a published default password — force a change at first login.
# Skipped on lab builds (ARYAOS_LAB_ACCESS=1: /etc/sudoers.d/aryaos-lab) and on
# hosts that already trust the aryaos-dev-lab key (images built before the gate).
PASS_EXPIRED_MARKER="/etc/aryaos/.default-pass-expired"
if [[ ! -f /etc/sudoers.d/aryaos-lab && ! -f "$PASS_EXPIRED_MARKER" ]] \
	&& ! grep -qs 'aryaos-dev-lab' /home/pi/.ssh/authorized_keys \
	&& getent passwd pi >/dev/null 2>&1; then
	if chage -d 0 pi; then
		touch "$PASS_EXPIRED_MARKER"
		echo "Default password for user pi expired; a new password is required at next login."
		CHANGED=1
	fi
fi

if [[ "$CHANGED" -eq 0 ]]; then
	echo "AryaOS firstboot: no changes needed."
	exit 0
fi
