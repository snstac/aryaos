#!/usr/bin/env bash
# 07-antsdr.sh — ANTSDR Ethernet + DroneCOT listener checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

ANTSDR_HOST_IP="${ARYAOS_ANTSDR_HOST_IP:-172.31.100.1}"
ANTSDR_DEVICE_IP="${ARYAOS_ANTSDR_DEVICE_IP:-172.31.100.2}"

if ip -4 addr show eth1 2>/dev/null | grep -q "${ANTSDR_HOST_IP}/24"; then
	ok "ANTSDR host address ${ANTSDR_HOST_IP}/24 on eth1"
else
	fail "ANTSDR host address ${ANTSDR_HOST_IP}/24 missing on eth1"
fi

if ip -4 addr show eth1 2>/dev/null | grep -q '192.168.1.9/24'; then
	ok "ANTSDR stock fallback host address 192.168.1.9/24 on eth1"
else
	warn "ANTSDR stock fallback host address 192.168.1.9/24 missing"
fi

if ping -c 2 -W 1 "${ANTSDR_DEVICE_IP}" >/dev/null 2>&1; then
	ok "ANTSDR ping ${ANTSDR_DEVICE_IP}"
else
	fail "ANTSDR ping ${ANTSDR_DEVICE_IP} failed"
fi

HTTP_CODE="$(curl -fsS --connect-timeout 2 -o /dev/null -w '%{http_code}' "http://${ANTSDR_DEVICE_IP}/" 2>/dev/null || true)"
if [[ "${HTTP_CODE}" == "200" ]]; then
	ok "ANTSDR HTTP ${HTTP_CODE}"
else
	warn "ANTSDR HTTP unavailable (code=${HTTP_CODE:-none})"
fi

if systemctl show dronecot -p ExecStartPre --value 2>/dev/null | grep -q .; then
	fail "dronecot ExecStartPre still configured"
else
	ok "dronecot ExecStartPre cleared"
fi

if ss -ltn "sport = :52002" | grep -q "${ANTSDR_HOST_IP}:52002"; then
	ok "dronecot listening on ${ANTSDR_HOST_IP}:52002"
else
	fail "dronecot not listening on ${ANTSDR_HOST_IP}:52002"
fi

ANTSDR_SESSION_OK=0
for _ in 1 2 3 4 5; do
	if ss -tn | grep -q "${ANTSDR_DEVICE_IP}:"; then
		ANTSDR_SESSION_OK=1
		break
	fi
	sleep 1
done
if [[ "${ANTSDR_SESSION_OK}" -eq 1 ]]; then
	ok "ANTSDR TCP session established"
else
	warn "ANTSDR TCP session not established"
fi

print_summary
