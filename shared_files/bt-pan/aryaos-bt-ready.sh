#!/bin/bash
# Ensure the built-in Bluetooth adapter is usable before dependent services start.

set -euo pipefail

ADAPTER="${BT_ADAPTER:-hci0}"
RFKILL="${RFKILL:-/usr/sbin/rfkill}"
BLUETOOTHCTL="${BLUETOOTHCTL:-/usr/bin/bluetoothctl}"
HCICONFIG="${HCICONFIG:-/usr/bin/hciconfig}"

log() {
	echo "aryaos-bt-ready: $*"
}

if [[ -x "${RFKILL}" ]]; then
	"${RFKILL}" unblock bluetooth || true
fi

systemctl start bluetooth.service

for _ in $(seq 1 20); do
	if [[ -d "/sys/class/bluetooth/${ADAPTER}" ]]; then
		break
	fi
	sleep 0.5
done

if [[ ! -d "/sys/class/bluetooth/${ADAPTER}" ]]; then
	log "${ADAPTER} did not appear"
	exit 1
fi

if [[ -x "${HCICONFIG}" ]]; then
	"${HCICONFIG}" "${ADAPTER}" up || true
fi

if [[ -x "${BLUETOOTHCTL}" ]]; then
	# The adapter directory appearing in sysfs does not mean bluetoothd has
	# registered a controller yet; issuing commands too early returns "No
	# default controller available" and, under set -e, failed the whole unit on
	# a box whose Bluetooth was otherwise fine. Wait for the controller, then
	# treat these as best-effort: Bluetooth PAN is an optional transport and
	# must not leave a failed unit behind.
	for _ in $(seq 1 20); do
		if timeout 5 "${BLUETOOTHCTL}" show >/dev/null 2>&1; then
			break
		fi
		sleep 0.5
	done
	timeout 8 "${BLUETOOTHCTL}" power on || log "power on failed (controller not ready)"
	timeout 8 "${BLUETOOTHCTL}" discoverable-timeout 0 || true
	timeout 8 "${BLUETOOTHCTL}" discoverable on || true
	timeout 8 "${BLUETOOTHCTL}" pairable on || true
fi

if [[ -r "/sys/class/bluetooth/${ADAPTER}/address" ]]; then
	log "${ADAPTER} ready ($(cat "/sys/class/bluetooth/${ADAPTER}/address"))"
else
	log "${ADAPTER} ready"
fi
