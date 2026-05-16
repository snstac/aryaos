#!/usr/bin/env bash
# Append AryaOS USB power settings to Raspberry Pi boot config (idempotent).
# Run on the Pi (or chroot) with sudo when multiple SDRs hit the USB current cap.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

MARKER="# --- AryaOS: USB peripheral power ---"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -z "${FRAG:-}" ]]; then
	for cand in \
		"${REPO_ROOT}/shared_files/aryaos/boot/firmware/aryaos-usb-power.fragment" \
		"${SCRIPT_DIR}/aryaos-usb-power.fragment"; do
		if [[ -f "${cand}" ]]; then
			FRAG="${cand}"
			break
		fi
	done
fi

if [[ -z "${FRAG:-}" || ! -f "${FRAG}" ]]; then
	echo "Missing aryaos-usb-power.fragment (set FRAG= path, or run from repo, or place fragment next to this script)." >&2
	exit 1
fi

CFG=""
for p in /boot/firmware/config.txt /boot/config.txt; do
	if [[ -f "${p}" ]]; then
		CFG="${p}"
		break
	fi
done

if [[ -z "${CFG}" ]]; then
	echo "No /boot/firmware/config.txt or /boot/config.txt found (not a Raspberry Pi image?)." >&2
	exit 1
fi

if grep -qF "${MARKER}" "${CFG}" 2>/dev/null; then
	echo "Already present in ${CFG} — nothing to do."
	exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Appending to ${CFG} (sudo)…"
	sudo tee -a "${CFG}" <"${FRAG}" >/dev/null
else
	cat "${FRAG}" >>"${CFG}"
fi

echo "Updated ${CFG}. Reboot the Pi for firmware to apply USB power settings."
