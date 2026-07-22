#!/usr/bin/env bash
# Configure readsb to use a LimeSDR (Mini) via SoapySDR and restart.
#
# For the "dragonegg" laydown (AryaOS + LimeSDR Mini + GPS): use the Lime as the
# 1090 MHz ADS-B front-end. Requires soapysdr-module-lms7 (shipped) — verify the
# device first with `LimeUtil --find` and `SoapySDRUtil --probe="driver=lime"`.
# A LimeSDR Mini often needs a one-time gateware update: `LimeUtil --update`.
#
# Usage:
#   sudo ./scripts/readsb-use-lime.sh
#   sudo ./scripts/readsb-use-lime.sh "driver=lime" 40
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

SOAPY_DEVICE="${1:-driver=lime}"
GAIN="${2:-40}"
READSB_DEF="/etc/default/readsb"

if [[ ! -f "${READSB_DEF}" ]]; then
	echo "Missing ${READSB_DEF} — is readsb installed?" >&2
	exit 1
fi

if ! /usr/bin/readsb --help 2>&1 | grep -q soapysdr; then
	echo "readsb lacks SoapySDR support — rebuild with SOAPYSDR=yes (readsb-install.sh)." >&2
	exit 1
fi

if ! SoapySDRUtil --info 2>&1 | grep -qi 'lime\|lms7'; then
	echo "SoapySDR has no LimeSDR (lms7) module — is soapysdr-module-lms7 installed?" >&2
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
