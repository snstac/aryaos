#!/usr/bin/env bash
# 11-wifi-rid.sh — enabled Wi-Fi Remote ID receiver hardware/runtime checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if ! systemctl is-enabled --quiet dronecot-wifi.service 2>/dev/null; then
	skip "Wi-Fi RID checks skipped (dronecot-wifi disabled)"
	print_summary
	exit 0
fi

CONFIG=/etc/default/dronecot-wifi
WIFI_INTERFACE="$(sed -n 's/^[[:space:]]*WIFI_INTERFACE=//p' "${CONFIG}" 2>/dev/null | tail -n 1)"
WIFI_INTERFACE="${WIFI_INTERFACE//[\"\']/}"

if unit_active dronecot-wifi; then
	ok "dronecot-wifi active"
else
	fail "dronecot-wifi enabled but not active"
fi

if [[ -n "${WIFI_INTERFACE}" && -e "/sys/class/net/${WIFI_INTERFACE}" ]]; then
	ok "Wi-Fi RID interface ${WIFI_INTERFACE} present"
else
	fail "configured Wi-Fi RID interface ${WIFI_INTERFACE:-unset} missing"
	print_summary
	exit 0
fi

DRIVER="$(basename "$(readlink -f "/sys/class/net/${WIFI_INTERFACE}/device/driver" 2>/dev/null)" 2>/dev/null || true)"
if [[ -n "${DRIVER}" ]]; then
	ok "Wi-Fi RID interface driver ${DRIVER}"
else
	fail "Wi-Fi RID interface has no bound driver"
fi

IFACE_TYPE="$(iw dev "${WIFI_INTERFACE}" info 2>/dev/null | awk '$1 == "type" {print $2; exit}')"
if [[ "${IFACE_TYPE}" == "monitor" ]]; then
	ok "Wi-Fi RID interface in monitor mode"
else
	fail "Wi-Fi RID interface type is ${IFACE_TYPE:-unknown}, expected monitor"
fi

RX_PACKETS=0
for _ in 1 2 3 4 5; do
	RX_PACKETS="$(cat "/sys/class/net/${WIFI_INTERFACE}/statistics/rx_packets" 2>/dev/null || echo 0)"
	[[ "${RX_PACKETS}" =~ ^[0-9]+$ && "${RX_PACKETS}" -gt 0 ]] && break
	sleep 1
done
if [[ "${RX_PACKETS}" =~ ^[0-9]+$ && "${RX_PACKETS}" -gt 0 ]]; then
	ok "Wi-Fi RID interface receiving packets (${RX_PACKETS})"
else
	fail "Wi-Fi RID interface has received no packets"
fi

RESTARTS="$(systemctl show dronecot-wifi -p NRestarts --value 2>/dev/null || true)"
if [[ "${RESTARTS}" == "0" ]]; then
	ok "dronecot-wifi has not restarted"
else
	fail "dronecot-wifi restart count ${RESTARTS:-unknown}"
fi

STATUS_JSON="$(sudo -n cat /run/dronecot/status.json 2>/dev/null || true)"
if python3 -c '
import json, sys
doc = json.load(sys.stdin)
assert doc.get("app") == "dronecot"
assert doc.get("feed") == "wifi"
assert doc.get("write_errors") == 0
' <<<"${STATUS_JSON}" 2>/dev/null; then
	ok "Wi-Fi RID runtime status healthy"
else
	fail "Wi-Fi RID runtime status missing or unhealthy"
fi

VERSION="$(dpkg-query -W -f='${Version}' dronecot 2>/dev/null || true)"
if [[ -n "${VERSION}" ]] && dpkg --compare-versions "${VERSION}" ge 2.3.7; then
	ok "dronecot runtime package ${VERSION}"
else
	fail "dronecot package ${VERSION:-missing}, expected >= 2.3.7"
fi

print_summary
