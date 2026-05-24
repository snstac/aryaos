#!/usr/bin/env bash
# Configure readsb for Airspy (SoapySDR) and restart.
#
# Usage:
#   sudo ./scripts/readsb-use-airspy.sh
#   sudo ./scripts/readsb-use-airspy.sh "driver=airspy" 18
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

SOAPY_DEVICE="${1:-driver=airspy}"
GAIN="${2:-15}"
READSB_DEF="/etc/default/readsb"

if [[ ! -f "${READSB_DEF}" ]]; then
	echo "Missing ${READSB_DEF} — is readsb installed?" >&2
	exit 1
fi

if ! /usr/bin/readsb --help 2>&1 | grep -q soapysdr; then
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

systemctl restart readsb
echo "=== readsb status ==="
systemctl --no-pager --full status readsb || true
