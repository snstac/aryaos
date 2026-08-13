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
	# Ensure the canonical Debian 127.0.1.1 hostname mapping. Drop any stale
	# aryaos / aryaos-xxxx entry first (match both 127.0.1.1 and a legacy
	# 127.0.0.1 line), then add the correct one. Robust to whatever state
	# /etc/hosts was left in — e.g. after a factory reset — and idempotent.
	sed -i -E '/^127\.0\.[01]\.1[[:space:]]+aryaos(-[0-9a-f]{4})?([[:space:]]|$)/d;/^::1[[:space:]]+aryaos(-[0-9a-f]{4})?([[:space:]]|$)/d' /etc/hosts
	printf '127.0.1.1\t%s\n' "${NEW_HOST}" >> /etc/hosts
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

# Node-RED ships a publicly known default admin password, and the editor runs
# arbitrary code as the node-red user. Randomize it once at first boot so the
# admin API on :1880 is not reachable with the published credential; the operator
# sets their own via Cockpit -> AryaOS Site. Skipped on lab builds (known creds
# for dev), matching the pi-password gate above.
NR_PASS_MARKER="/etc/aryaos/.nodered-pass-randomized"
if [[ ! -f /etc/sudoers.d/aryaos-lab && ! -f "$NR_PASS_MARKER" ]] \
	&& [[ -f /home/node-red/.node-red/settings.js ]] \
	&& [[ -x /usr/local/sbin/aryaos-set-nodered-password ]]; then
	if head -c 18 /dev/urandom | base64 | /usr/local/sbin/aryaos-set-nodered-password >/dev/null 2>&1; then
		touch "$NR_PASS_MARKER"
		echo "Node-RED admin password randomized; set your own in Cockpit -> AryaOS Site."
		CHANGED=1
	fi
fi

# Auto-configure sensor capabilities from attached hardware.
#
# The image ships every sensor gateway disabled, because a box with no radios
# should be quiet rather than crash-looping decoders. On first boot we look at
# what is actually plugged in and turn on what it supports, so a kitted unit is
# plug-and-play while a bare one stays silent. Runs ONCE (marker file) so a
# later deliberate `aryaos-role caps ...` is never overwritten.
CAP_MARKER="/etc/aryaos/.capabilities-autodetected"
CAP_TRIES="/etc/aryaos/.capabilities-autodetect-tries"
CAP_MAX_TRIES=3
if [[ ! -f "$CAP_MARKER" ]] \
	&& [[ -x /usr/local/sbin/aryaos-role ]] \
	&& [[ -x /usr/local/sbin/aryaos-capability-scan ]]; then
	# Wait for USB to finish enumerating before believing an empty result. A
	# LimeSDR was present at 3.7s on a real first boot but the scan still came
	# back empty, because SoapySDRUtil blocks activating Avahi over dbus this
	# early; the box then recorded "bare node" permanently.
	udevadm settle --timeout=30 >/dev/null 2>&1 || true
	# Accumulate the UNION across tries, and stop only once two consecutive
	# scans agree.
	#
	# This loop used to break on the first NON-EMPTY result, which guarded
	# against seeing nothing but not against seeing only PART of the kit. Buses
	# come up at very different speeds: on aryaos-4f11 the AntSDR sits on a
	# point-to-point Ethernet link and answered immediately, while the DroneScout
	# is an ESP32 on USB that had not started streaming MAVLink yet. Try 1
	# returned "dji", the loop broke, and the box latched caps="dji" with the
	# Remote ID receiver plugged in and idle -- and because the marker file is
	# then written, autodetect never looks again.
	#
	# Union rather than last-wins, so a device that answers once and is busy on a
	# later pass cannot be dropped again. The probes only ever report hardware
	# they can see, so this cannot invent a capability.
	DETECTED=""
	_prev=""
	for _try in 1 2 3; do
		_this="$(/usr/local/sbin/aryaos-capability-scan --caps 2>/dev/null \
			| tr ' ' '\n' | sed '/^$/d' | sort -u | xargs || true)"
		DETECTED="$(printf '%s %s' "${DETECTED}" "${_this}" \
			| tr ' ' '\n' | sed '/^$/d' | sort -u | xargs || true)"
		# Settled: same set twice running, and not empty.
		[[ -n "${_this}" && "${_this}" == "${_prev}" ]] && break
		_prev="${_this}"
		[[ "${_try}" -lt 3 ]] && sleep 10
	done

	if [[ -n "$DETECTED" ]]; then
		# The multi-pass union above is authoritative, but capability names alone
		# are not enough: ADSBee and DroneScout also need their verified serial
		# transports written before the services start.
		if /usr/local/sbin/aryaos-role apply-detected $DETECTED >/dev/null 2>&1; then
			echo "AryaOS firstboot: detected hardware -> capabilities: $DETECTED"
			CHANGED=1
		fi
		touch "$CAP_MARKER"
	else
		# Do NOT latch "bare" on one look: a slow device, a sensor plugged in
		# later, or a service that was not up yet all deserve another attempt on
		# the next boot. Give up after CAP_MAX_TRIES so a genuinely bare relay
		# node stops scanning.
		TRIES=$(( $(cat "$CAP_TRIES" 2>/dev/null || echo 0) + 1 ))
		echo "$TRIES" > "$CAP_TRIES"
		if [[ "$TRIES" -ge "$CAP_MAX_TRIES" ]]; then
			echo "AryaOS firstboot: no sensor hardware after ${TRIES} boots; staying a bare CoT node."
			touch "$CAP_MARKER"
		else
			echo "AryaOS firstboot: no sensor hardware detected (attempt ${TRIES}/${CAP_MAX_TRIES}); will retry next boot."
		fi
	fi
fi

if [[ "$CHANGED" -eq 0 ]]; then
	echo "AryaOS firstboot: no changes needed."
	exit 0
fi
