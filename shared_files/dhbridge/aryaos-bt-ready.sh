#!/bin/bash
# Ensure the built-in Bluetooth adapter is usable before dhbridge starts.

set -euo pipefail

ADAPTER="${DHBRIDGE_BT_ADAPTER:-${BT_ADAPTER:-hci0}}"
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
	timeout 8 "${BLUETOOTHCTL}" power on
	timeout 8 "${BLUETOOTHCTL}" discoverable on
	timeout 8 "${BLUETOOTHCTL}" pairable on
fi

if [[ -r "/sys/class/bluetooth/${ADAPTER}/address" ]]; then
	log "${ADAPTER} ready ($(cat "/sys/class/bluetooth/${ADAPTER}/address"))"
else
	log "${ADAPTER} ready"
fi
