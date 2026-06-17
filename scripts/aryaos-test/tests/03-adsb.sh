#!/usr/bin/env bash
# 03-adsb.sh — readsb SDR build and aircraft.json checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if test_profile uas; then
	skip "ADS-B decoder checks skipped on UAS profile"
	print_summary
	exit 0
fi

READSB_HELP=""
if command -v readsb >/dev/null; then
	READSB_HELP="$(readsb --help 2>&1 || true)"
fi

if apt-mark showhold 2>/dev/null | grep -qx readsb; then
	ok "readsb apt hold active"
fi

if [[ -z "${READSB_HELP}" ]]; then
	fail "readsb binary not found"
else
	if echo "${READSB_HELP}" | grep -qE 'RTL-SDR|rtlsdr'; then
		ok "readsb RTL-SDR support"
	else
		fail "readsb missing RTL-SDR support"
	fi
	if echo "${READSB_HELP}" | grep -qiE 'SoapySDR|soapysdr'; then
		ok "readsb SoapySDR support"
	else
		fail "readsb missing SoapySDR support"
	fi
	if echo "${READSB_HELP}" | grep -qiE 'HackRF|hackrf'; then
		ok "readsb HackRF support"
	else
		fail "readsb missing HackRF support"
	fi
fi

JSON_PATH="/run/adsb/aircraft.json"
if [[ ! -f "${JSON_PATH}" ]]; then
	fail "${JSON_PATH} missing"
else
	ok "${JSON_PATH} exists"
	set +e
	python3 - <<'PY'
import json
import sys
from pathlib import Path

path = Path("/run/adsb/aircraft.json")
try:
    data = json.loads(path.read_text())
except json.JSONDecodeError:
    sys.exit(1)

aircraft = data.get("aircraft")
if isinstance(aircraft, list):
    sys.exit(0 if len(aircraft) > 0 else 2)
sys.exit(2)
PY
	rc=$?
	set -e
	case "${rc}" in
		0) ok "aircraft.json valid with traffic" ;;
		2) warn "aircraft.json empty (no ADS-B traffic)" ;;
		*) fail "aircraft.json invalid JSON" ;;
	esac
fi

echo "--- readsb (last 5 log lines) ---"
journalctl -u readsb -n 5 --no-pager 2>/dev/null || true

print_summary
