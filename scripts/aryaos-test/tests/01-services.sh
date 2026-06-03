#!/usr/bin/env bash
# 01-services.sh — systemd service checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

TIER="${ARYAOS_TEST_TIER:-default}"

for svc in readsb adsbcot lighttpd gpsd; do
	if unit_active "${svc}"; then
		ok "${svc} active"
	else
		fail "${svc} not active"
	fi
done

for svc in charontak lincot adsbcot aiscot dronecot; do
	if ! unit_loaded "${svc}"; then
		fail "TAK gateway unit ${svc} missing (portal expects it)"
		continue
	fi
	if unit_active "${svc}"; then
		ok "TAK gateway ${svc} active"
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
