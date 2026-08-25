#!/usr/bin/env bash
# 07-antsdr.sh — ANTSDR Ethernet + DroneCOT listener checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if ! test_profile uas; then
	skip "ANTSDR checks skipped outside UAS profile"
	print_summary
	exit 0
fi

ANTSDR_HOST_IP="${ARYAOS_ANTSDR_HOST_IP:-}"
ANTSDR_DEVICE_IP="${ARYAOS_ANTSDR_DEVICE_IP:-}"

if [[ -z "${ANTSDR_HOST_IP}" && -r /etc/default/dronecot-dji ]]; then
	ANTSDR_HOST_IP="$(sed -n 's/^DJI_BIND_ADDRESS=//p' /etc/default/dronecot-dji | tail -1)"
fi
ANTSDR_HOST_IP="${ANTSDR_HOST_IP:-172.31.100.1}"

if [[ -z "${ANTSDR_DEVICE_IP}" && -x /usr/local/sbin/aryaos-antsdr-health ]]; then
	ANTSDR_DEVICE_IP="$(sudo -n /usr/local/sbin/aryaos-antsdr-health --quiet --json 2>/dev/null | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("antsdr_ip", ""))
except (json.JSONDecodeError, OSError):
    pass
' 2>/dev/null || true)"
fi
if [[ -z "${ANTSDR_DEVICE_IP}" ]]; then
	ANTSDR_DEVICE_IP="$(python3 -c '
import ipaddress, sys
try:
    print(ipaddress.ip_address(sys.argv[1]) + 1)
except ValueError:
    pass
' "${ANTSDR_HOST_IP}")"
fi

if ip -4 -o addr show eth1 2>/dev/null | awk '{print $4}' | grep -qE "^${ANTSDR_HOST_IP//./\\.}/[0-9]+$"; then
	ok "ANTSDR host address ${ANTSDR_HOST_IP} on eth1"
else
	fail "ANTSDR host address ${ANTSDR_HOST_IP} missing on eth1"
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

if ! systemctl show dronecot-dji -p ExecCondition --value 2>/dev/null | grep -q 'aryaos-dronecot-ready'; then
	fail "dronecot-dji bind-address condition missing"
else
	ok "dronecot-dji bind-address condition installed"
fi

if ss -ltn "sport = :52002" | grep -q "${ANTSDR_HOST_IP}:52002"; then
	ok "dronecot-dji listening on ${ANTSDR_HOST_IP}:52002"
else
	fail "dronecot-dji not listening on ${ANTSDR_HOST_IP}:52002"
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

if [[ -x /usr/local/sbin/aryaos-antsdr-health ]]; then
	HEALTH_JSON="$(sudo -n /usr/local/sbin/aryaos-antsdr-health --quiet --json 2>/dev/null || true)"
	if python3 -c '
import json, sys
doc = json.load(sys.stdin)
assert "tak_established" in doc
assert doc["tak_established"] in (True, False, None)
' <<<"${HEALTH_JSON}" 2>/dev/null; then
		ok "ANTSDR health reports TAK egress state"
	else
		fail "ANTSDR health missing valid tak_established state"
	fi
fi

print_summary
