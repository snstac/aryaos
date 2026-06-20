#!/usr/bin/env bash
# 01-services.sh — systemd service checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

TIER="${ARYAOS_TEST_TIER:-default}"

FAILED_UNITS="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd ' ' -)"
if [[ -n "${FAILED_UNITS}" ]]; then
	fail "system has failed units: ${FAILED_UNITS}"
else
	ok "no failed systemd units"
fi

if test_profile uas; then
	CORE_SERVICES=(lighttpd gpsd)
else
	CORE_SERVICES=(readsb adsbcot lighttpd gpsd)
fi

for svc in "${CORE_SERVICES[@]}"; do
	if unit_active "${svc}"; then
		ok "${svc} active"
	else
		fail "${svc} not active"
	fi
done

if unit_loaded aryaos-gps-time-sync && systemctl is-enabled --quiet aryaos-gps-time-sync.service 2>/dev/null; then
	ok "aryaos-gps-time-sync installed and enabled"
else
	fail "aryaos-gps-time-sync not installed/enabled"
fi

if test_profile uas; then
	for svc in readsb adsbcot dump1090-fa dump978-fa; do
		if unit_active "${svc}"; then
			fail "${svc} active on UAS profile"
		elif systemctl is-active "${svc}" 2>/dev/null | grep -qE 'activating|reloading|deactivating'; then
			fail "${svc} restarting on UAS profile"
		else
			skip "${svc} inactive on UAS profile"
		fi
	done
else
	for svc in dump978-fa; do
		if unit_loaded "${svc}" && systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
			if unit_active "${svc}"; then
				ok "${svc} active"
			elif systemctl is-active "${svc}" 2>/dev/null | grep -qE 'activating|reloading|deactivating'; then
				fail "${svc} restarting"
			else
				fail "${svc} enabled but not active"
			fi
		fi
	done
fi

for svc in charontak lincot adsbcot aiscot dronecot sikw00fcot; do
	if ! unit_loaded "${svc}"; then
		fail "TAK gateway unit ${svc} missing (portal expects it)"
		continue
	fi
	if unit_active "${svc}"; then
		ok "TAK gateway ${svc} active"
	elif test_profile uas && [[ "${svc}" == "adsbcot" ]]; then
		skip "TAK gateway ${svc} inactive on UAS profile"
	elif ! test_profile uas && [[ "${svc}" == "dronecot" ]]; then
		skip "TAK gateway ${svc} inactive outside UAS profile"
	elif [[ "${svc}" == "sikw00fcot" ]]; then
		warn "TAK gateway ${svc} loaded but not active (SiK radio/fan-out optional)"
	else
		warn "TAK gateway ${svc} loaded but not active"
	fi
done

if unit_loaded dhbridge; then
	if unit_active dhbridge; then
		ok "dhbridge active"
	else
		warn "dhbridge installed but not active"
	fi
else
	warn "dhbridge unit not installed (older image?)"
fi

print_summary
