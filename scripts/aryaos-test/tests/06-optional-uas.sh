#!/usr/bin/env bash
# 06-optional-uas.sh — DroneScout / MQTT / BT warn-only checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if command -v docker >/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
	ok "docker active"
	if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi mqtt; then
		ok "mqtt docker container running"
	else
		warn "no mqtt broker container visible (DroneScout stack down?)"
	fi
else
	warn "docker not active (dronecot UAS stack optional)"
fi

if command -v mosquitto_sub >/dev/null; then
	if timeout 3 mosquitto_sub -h localhost -t '#' -C 1 >/dev/null 2>&1; then
		ok "MQTT broker reachable on localhost"
	else
		warn "MQTT localhost not responding (no DroneScout traffic)"
	fi
else
	warn "mosquitto_sub not installed"
fi

if [[ -d /sys/class/bluetooth/hci0 ]]; then
	ok "Bluetooth hci0 present"
else
	warn "Bluetooth hci0 not found (dronehone-bridge needs BT adapter)"
fi

if unit_loaded dronecot; then
	if unit_active dronecot; then
		ok "dronecot active"
	else
		warn "dronecot not active"
	fi
fi

print_summary
