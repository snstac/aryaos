#!/usr/bin/env bash
# 13-ais.sh — active AIS receiver and private data-path checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if ! capability_enabled ais; then
	skip "AIS checks skipped (ais capability disabled)"
	print_summary
	exit 0
fi

receiver_service=ais-catcher
if unit_active aryaos-ais-sdr; then
	receiver_service=aryaos-ais-sdr
fi

for svc in "${receiver_service}" aiscot; do
	if unit_active "${svc}"; then
		ok "${svc} active"
	else
		fail "${svc} not active for ais capability"
	fi
	restarts="$(systemctl show "${svc}.service" -p NRestarts --value 2>/dev/null || true)"
	if [[ "${restarts}" == "0" ]]; then
		ok "${svc} has not entered a restart loop"
	else
		fail "${svc} has ${restarts:-unknown} systemd restarts"
	fi
done

serial_port=""
if [[ "${receiver_service}" == aryaos-ais-sdr ]]; then
	device_args="$(sed -n 's/^AIS_CATCHER_DEVICE_ARGS=//p' /etc/default/aryaos-ais-sdr 2>/dev/null | tail -1 | tr -d '"')"
	if { [[ "${device_args}" == *"DEVICE driver="* ]] || [[ "${device_args}" == -d\ * ]]; } \
		&& grep -q '=ais$' /etc/aryaos/sdr-tasks 2>/dev/null; then
		ok "AIS receiver has a persistent SDR selector"
	else
		fail "AIS SDR selector is absent or invalid (${device_args:-unset})"
	fi
elif serial_port="$(sed -n 's/^SERIAL_PORT=//p' /etc/default/ais-catcher 2>/dev/null | tail -1 | tr -d '"')" \
	&& [[ "${serial_port}" == /dev/serial/by-id/* && -e "${serial_port}" ]]; then
	ok "AIS receiver pinned to a present by-id device"
else
	fail "AIS SERIAL_PORT is absent, unstable, or missing (${serial_port:-unset})"
fi

gps_port="$(sed -n 's/^DEVICES=//p' /etc/default/gpsd 2>/dev/null | tail -1 | tr -d '"')"
if [[ -n "${serial_port}" && -n "${gps_port}" ]] \
	&& [[ "$(readlink -f "${serial_port}" 2>/dev/null)" == "$(readlink -f "${gps_port}" 2>/dev/null)" ]]; then
	fail "AIS and GPS are assigned to the same serial device"
else
	ok "AIS and GPS serial assignments are isolated"
fi

if systemctl show "${receiver_service}.service" -p ExecStart --value 2>/dev/null | grep -Fq -- '-X off'; then
	ok "AIS-catcher internet community sharing explicitly disabled"
else
	fail "AIS-catcher does not explicitly disable internet community sharing"
fi

if ss -lnt 2>/dev/null | grep -qE 'LISTEN .*:8100[[:space:]]'; then
	ok "AIS-catcher dashboard listening on TCP/8100"
else
	fail "AIS-catcher dashboard not listening on TCP/8100"
fi

if ss -lnu 2>/dev/null | grep -qE 'UNCONN .*:5050[[:space:]]'; then
	ok "aiscot listening for decoder output on UDP/5050"
else
	fail "aiscot not listening on UDP/5050"
fi

recent_ais="$(journalctl -u "${receiver_service}.service" --since "10 minutes ago" --no-pager 2>/dev/null || true)"
if grep -q '!AIVDM' <<<"${recent_ais}"; then
	ok "live AIS NMEA observed in the last 10 minutes"
else
	warn "no live AIS NMEA observed in the last 10 minutes (RF traffic may be quiet)"
fi

print_summary
