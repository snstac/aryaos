#!/usr/bin/env bash
# 14-acars.sh — DragonEgg ACARS receiver and private decoder-path checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if ! capability_enabled acars; then
	skip "ACARS checks skipped (acars capability disabled)"
	print_summary
	exit 0
fi

for svc in acarsdec acarscot; do
	if unit_active "${svc}"; then
		ok "${svc} active"
	else
		fail "${svc} not active for acars capability"
	fi
	restarts="$(systemctl show "${svc}.service" -p NRestarts --value 2>/dev/null || true)"
	if [[ "${restarts}" == "0" ]]; then
		ok "${svc} has not entered a restart loop"
	else
		fail "${svc} has ${restarts:-unknown} systemd restarts"
	fi
done

device_args="$(sed -n 's/^ACARSDEC_DEVICE_ARGS=//p' /etc/default/acarsdec 2>/dev/null | tail -1 | tr -d '"')"
frequencies="$(sed -n 's/^ACARSDEC_FREQS=//p' /etc/default/acarsdec 2>/dev/null | tail -1 | tr -d '"')"
json_host="$(sed -n 's/^ACARSDEC_JSON_HOST=//p' /etc/default/acarsdec 2>/dev/null | tail -1 | tr -d '"')"
json_port="$(sed -n 's/^ACARSDEC_JSON_PORT=//p' /etc/default/acarsdec 2>/dev/null | tail -1 | tr -d '"')"

if [[ -n "${device_args}" ]] && grep -qE -- '--(soapysdr|rtlsdr)' <<<"${device_args}"; then
	ok "ACARS decoder has an explicit SDR selection"
else
	fail "ACARS decoder SDR selection is missing or unsupported (${device_args:-unset})"
fi

if grep -q 'driver=lime' <<<"${device_args}"; then
	if grep -Riq lime /sys/bus/usb/devices/*/{manufacturer,product} 2>/dev/null; then
		ok "configured LimeSDR is present in USB inventory"
	else
		fail "ACARS is configured for LimeSDR but no Lime descriptor is present"
	fi
	if journalctl -u acarsdec.service -b --no-pager 2>/dev/null | grep -q 'Make connection:.*LimeSDR'; then
		ok "acarsdec opened the LimeSDR in this boot"
	else
		fail "acarsdec has no successful LimeSDR connection in this boot"
	fi
fi

if [[ "${json_host}" == "127.0.0.1" || "${json_host}" == "::1" ]]; then
	ok "acarsdec JSON output is loopback-only"
else
	fail "acarsdec JSON output is not loopback-only (${json_host:-unset})"
fi

if [[ "${json_port}" =~ ^[0-9]+$ ]] \
	&& sudo -n ss -lunp 2>/dev/null | grep -qE ":${json_port}[[:space:]].*acarscot"; then
	ok "acarscot is listening for decoder JSON on UDP/${json_port}"
else
	fail "acarscot is not listening on configured UDP/${json_port:-unset}"
fi

frequency_count="$(wc -w <<<"${frequencies}")"
if [[ "${frequency_count}" -ge 1 && "${frequency_count}" -le 8 ]]; then
	ok "acarsdec has ${frequency_count} channel(s) configured"
else
	fail "acarsdec frequency list must contain 1-8 channels (${frequencies:-unset})"
fi

recent_acars="$(journalctl -u acarsdec.service --since '30 minutes ago' --no-pager 2>/dev/null || true)"
if grep -qE 'registration|flight|message|ARINC|ACARS' <<<"${recent_acars}"; then
	ok "live ACARS decoder activity observed in the last 30 minutes"
else
	warn "no live ACARS message observed in the last 30 minutes (RF traffic may be quiet)"
fi

print_summary
