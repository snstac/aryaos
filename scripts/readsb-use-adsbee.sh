#!/usr/bin/env bash
# Point readsb at an attached ADSBee (hardware 1090 Mode S + 978 UAT receiver),
# then restart the ADS-B pipeline. Run on the AryaOS host (needs root).
#
# Normally you do not need this: ARYAOS_ADSB_RECEIVER defaults to "auto", so an
# attached ADSBee is detected at boot and preferred over an SDR automatically.
# Use this to pin the choice on a box that also has an SDR, or to re-run
# detection after plugging one in.
#
# Usage:
#   sudo ./scripts/readsb-use-adsbee.sh          # pin readsb to the ADSBee
#   sudo ./scripts/readsb-use-adsbee.sh --auto   # back to automatic selection
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

MODE="adsbee"
if [[ "${1:-}" == "--auto" ]]; then
	MODE="auto"
elif [[ -n "${1:-}" ]]; then
	echo "Usage: sudo $0 [--auto]" >&2
	exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Run as root (sudo)." >&2
	exit 1
fi

AOS_CFG="/etc/aryaos/aryaos-config.txt"
if [[ ! -f "${AOS_CFG}" ]]; then
	echo "Missing ${AOS_CFG} — is this an AryaOS box?" >&2
	exit 1
fi

if grep -qE '^#?\s*ARYAOS_ADSB_RECEIVER=' "${AOS_CFG}"; then
	sed -i "s|^#\?\s*ARYAOS_ADSB_RECEIVER=.*|ARYAOS_ADSB_RECEIVER=${MODE}|" "${AOS_CFG}"
else
	printf 'ARYAOS_ADSB_RECEIVER=%s\n' "${MODE}" >>"${AOS_CFG}"
fi
echo "ARYAOS_ADSB_RECEIVER=${MODE}"

# readsb holds the ADSBee's serial port while it runs, so detection has to
# happen with readsb stopped — a probe cannot share the port with a Beast stream.
systemctl stop readsb >/dev/null 2>&1 || true
/usr/local/sbin/aryaos-adsbee provision || true

if [[ "${MODE}" == "adsbee" ]] && ! grep -q '^ARYAOS_ADSBEE_PRESENT=1' /run/aryaos/adsbee.env 2>/dev/null; then
	echo "WARNING: no ADSBee detected — readsb will not start until one is attached." >&2
fi

# Re-apply the capability set so dump978-fa is dropped (an ADSBee already covers
# 978 UAT) or restored (back on an SDR), rather than left crash-looping.
CAPS="$(sed -n 's/^ARYAOS_CAPABILITIES="\?\([^"]*\)"\?$/\1/p' "${AOS_CFG}" | tail -1)"
if [[ " ${CAPS} " == *" adsb "* ]]; then
	# Unquoted on purpose: `aryaos-role caps` takes one capability per argument.
	# shellcheck disable=SC2086
	/usr/local/sbin/aryaos-role caps ${CAPS} || true
else
	systemctl start readsb || true
fi

echo ""
echo "=== detection ==="
/usr/local/sbin/aryaos-adsbee info || true

echo ""
echo "=== readsb ==="
systemctl --no-pager --full status readsb || true

echo ""
echo "Confirm aircraft are arriving:  jq '.aircraft | length' /run/adsb/aircraft.json"
echo "UAT traffic shows up as type \"adsr_icao\" — the ADSBee sends 978 UAT in the"
echo "same Beast stream (frame type 0xec) and readsb converts it via uat2esnt."
