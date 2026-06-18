#!/usr/bin/env bash
# 06-optional-uas.sh — DroneScout / MQTT / Bluetooth checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if command -v docker >/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
	ok "docker active"
	if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi mqtt; then
		ok "mqtt docker container running"
	else
		skip "local MQTT broker container not configured by default"
	fi
else
	warn "docker not active (dronecot UAS stack optional)"
fi

if command -v mosquitto_sub >/dev/null && ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:|\])1883$'; then
	if timeout 3 mosquitto_sub -h localhost -t '#' -C 1 >/dev/null 2>&1; then
		ok "MQTT broker reachable on localhost"
	else
		warn "MQTT localhost not responding (no DroneScout traffic)"
	fi
elif command -v mosquitto_sub >/dev/null; then
	skip "mosquitto_sub installed but no local MQTT listener"
else
	skip "mosquitto_sub not installed; local MQTT broker not configured by default"
fi

RFKILL="$(command -v rfkill || true)"
[[ -z "${RFKILL}" && -x /usr/sbin/rfkill ]] && RFKILL=/usr/sbin/rfkill
HCICONFIG="$(command -v hciconfig || true)"

if [[ -d /sys/class/bluetooth/hci0 ]]; then
	ok "Bluetooth hci0 present"

	if [[ -n "${RFKILL}" ]]; then
		BT_RFKILL="$("${RFKILL}" list 2>/dev/null | awk '
			/^[0-9]+: hci0: Bluetooth/ { in_bt=1; print; next }
			/^[0-9]+:/ { in_bt=0 }
			in_bt { print }
		')"
		if grep -q 'Soft blocked: yes' <<<"${BT_RFKILL}"; then
			fail "Bluetooth hci0 soft-blocked"
		elif grep -q 'Hard blocked: yes' <<<"${BT_RFKILL}"; then
			fail "Bluetooth hci0 hard-blocked"
		else
			ok "Bluetooth hci0 not rfkill-blocked"
		fi
	else
		warn "rfkill not available"
	fi

	if command -v bluetoothctl >/dev/null; then
		BT_SHOW="$(bluetoothctl show 2>/dev/null || true)"
		grep -q 'Powered: yes' <<<"${BT_SHOW}" && ok "Bluetooth powered" || fail "Bluetooth not powered"
		grep -q 'Discoverable: yes' <<<"${BT_SHOW}" && ok "Bluetooth discoverable" || fail "Bluetooth not discoverable"
		grep -q 'Pairable: yes' <<<"${BT_SHOW}" && ok "Bluetooth pairable" || fail "Bluetooth not pairable"
	else
		warn "bluetoothctl not available"
	fi

	if [[ -n "${HCICONFIG}" ]]; then
		"${HCICONFIG}" hci0 2>/dev/null | grep -q 'UP RUNNING' && ok "Bluetooth hci0 UP RUNNING" || fail "Bluetooth hci0 not UP RUNNING"
	else
		warn "hciconfig not available"
	fi
else
	fail "Bluetooth hci0 not found (dhbridge needs BT adapter)"
fi

if unit_loaded dronecot; then
	if unit_active dronecot; then
		ok "dronecot active"
	elif test_profile uas; then
		warn "dronecot not active"
	else
		skip "dronecot inactive outside UAS profile"
	fi
fi

if unit_active dhbridge; then
	HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
	DHBRIDGE_BT_NAME="$(journalctl -u dhbridge --grep 'broadcast name' -n 1 --no-pager 2>/dev/null | sed -n "s/.*broadcast name '\([^']*\)'.*/\1/p" | tail -n1)"
	if [[ "${DHBRIDGE_BT_NAME}" == "${HOSTNAME_SHORT}" ]]; then
		ok "dhbridge broadcast name matches hostname (${HOSTNAME_SHORT})"
	elif [[ -n "${DHBRIDGE_BT_NAME}" ]]; then
		fail "dhbridge broadcast name ${DHBRIDGE_BT_NAME} does not match hostname ${HOSTNAME_SHORT}"
	else
		warn "dhbridge broadcast name not found in journal"
	fi
fi

print_summary
