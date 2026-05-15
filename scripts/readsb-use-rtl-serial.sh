#!/usr/bin/env bash
# Point readsb at a specific RTL-SDR EEPROM serial, then restart readsb.
# Run on the AryaOS host (needs root). Discover serials with: rtl_test
#
# Usage:
#   sudo ./scripts/readsb-use-rtl-serial.sh 2002
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

SERIAL="${1:-}"
if [[ -z "${SERIAL}" ]]; then
	echo "Usage: sudo $0 <rtl_eeprom_serial>" >&2
	echo "List dongles: rtl_test   (use the Serial number string verbatim)" >&2
	exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run as root (sudo)." >&2
	exit 1
fi

READSB_DEF="/etc/default/readsb"
if [[ ! -f "${READSB_DEF}" ]]; then
	echo "Missing ${READSB_DEF} — is readsb installed?" >&2
	exit 1
fi

AOS_CFG="/etc/aryaos/aryaos-config.txt"
if [[ -f "${AOS_CFG}" ]] && grep -q '^ARYAOS_UAT_RTL_SERIAL=' "${AOS_CFG}"; then
	uat="$(grep -m1 '^ARYAOS_UAT_RTL_SERIAL=' "${AOS_CFG}" | cut -d= -f2- | tr -d '"' | tr -d "'")"
	if [[ -n "${uat}" && "${uat}" == "${SERIAL}" ]]; then
		echo "ERROR: ARYAOS_UAT_RTL_SERIAL in ${AOS_CFG} is also '${SERIAL}'." >&2
		echo "1090 (readsb) and 978 (dump978-fa) must use different dongles — change UAT first." >&2
		exit 1
	fi
fi

if [[ -f /etc/default/dump978-fa ]] && grep -qF "serial=${SERIAL}" /etc/default/dump978-fa; then
	echo "ERROR: /etc/default/dump978-fa references serial=${SERIAL} — pick a different dongle for 1090." >&2
	exit 1
fi

python3 - "${READSB_DEF}" "${SERIAL}" <<'PY'
import re
import sys

path, serial = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
	lines = f.readlines()
out = []
changed = False
for line in lines:
	if line.startswith("RECEIVER_OPTIONS="):
		m = re.match(r'^RECEIVER_OPTIONS="([^"]*)"\s*$', line.rstrip("\n"))
		if not m:
			sys.stderr.write(f"Unparseable RECEIVER_OPTIONS line in {path}\n")
			sys.exit(1)
		inner = m.group(1)

		def pick(flag, default):
			mo = re.search(rf"(?:^|\s){re.escape(flag)}(?:=|\s+)(\S+)", inner)
			return mo.group(1) if mo else default

		gain = pick("--gain", "-10")
		ppm = pick("--ppm", "0")
		# readsb requires --device-type before any SDR-specific flags (see readsb --help).
		line = f'RECEIVER_OPTIONS="--device-type rtlsdr --device {serial} --gain {gain} --ppm {ppm}"\n'
		changed = True
	out.append(line)
if not changed:
	sys.stderr.write(f"No RECEIVER_OPTIONS= line in {path}\n")
	sys.exit(1)
with open(path, "w", encoding="utf-8") as f:
	f.writelines(out)
PY

systemctl restart readsb

echo "=== readsb status ==="
systemctl --no-pager --full status readsb || true

echo ""
echo "=== readsb journal (last 30 lines) ==="
journalctl -u readsb -b --no-pager | tail -n 30

echo ""
echo "Updated ${READSB_DEF} — confirm aircraft.json updates under the path in ADSB_JSON / --write-json."
