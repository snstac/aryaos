#!/usr/bin/env bash
# Configure readsb for HackRF (native or SoapySDR) and restart.
#
# Usage:
#   sudo ./scripts/readsb-use-hackrf.sh
#   sudo ./scripts/readsb-use-hackrf.sh 20
#   sudo ./scripts/readsb-use-hackrf.sh soapy driver=hackrf 20
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

READSB_DEF="/etc/default/readsb"

if [[ ! -f "${READSB_DEF}" ]]; then
	echo "Missing ${READSB_DEF} — is readsb installed?" >&2
	exit 1
fi

READSB_HELP="$(/usr/bin/readsb --help 2>&1)"

if [[ "${1:-}" == "soapy" ]]; then
	SOAPY_DEVICE="${2:-driver=hackrf}"
	GAIN="${3:-20}"
	if ! echo "${READSB_HELP}" | grep -qi soapysdr; then
		echo "readsb lacks SoapySDR support — rebuild with SOAPYSDR=yes (readsb-install.sh)." >&2
		exit 1
	fi
	python3 - "${READSB_DEF}" "${SOAPY_DEVICE}" "${GAIN}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
soapy = sys.argv[2]
gain = sys.argv[3]
text = path.read_text()
line = f'RECEIVER_OPTIONS="--device-type soapysdr --soapy-device {soapy} --gain {gain}"\n'
if re.search(r"^RECEIVER_OPTIONS=", text, re.M):
    text = re.sub(r"^RECEIVER_OPTIONS=.*$", line.rstrip(), text, count=1, flags=re.M)
else:
    text = text.rstrip() + "\n" + line
path.write_text(text)
PY
else
	GAIN="${1:-20}"
	if ! echo "${READSB_HELP}" | grep -qiE 'HackRF|hackrf'; then
		echo "readsb lacks HackRF support — rebuild with HACKRF=yes (readsb-install.sh)." >&2
		exit 1
	fi
	python3 - "${READSB_DEF}" "${GAIN}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
gain = sys.argv[2]
text = path.read_text()
line = f'RECEIVER_OPTIONS="--device-type hackrf --gain {gain}"\n'
if re.search(r"^RECEIVER_OPTIONS=", text, re.M):
    text = re.sub(r"^RECEIVER_OPTIONS=.*$", line.rstrip(), text, count=1, flags=re.M)
else:
    text = text.rstrip() + "\n" + line
path.write_text(text)
PY
fi

systemctl restart readsb
echo "=== readsb status ==="
systemctl --no-pager --full status readsb || true
