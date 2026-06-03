#!/bin/bash
# aryaos-device-suffix.sh — last 4 hex chars from machine-id or MAC (lowercase).
# Sourced by aryaos-firstboot.sh and run_comitup.sh.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

device_suffix() {
	local id mac iface iface_path

	if [[ -r /etc/machine-id ]]; then
		id="$(tr -d '[:space:]' < /etc/machine-id)"
		if [[ ${#id} -ge 4 ]]; then
			echo "${id: -4}" | tr '[:upper:]' '[:lower:]'
			return 0
		fi
	fi

	for iface in eth0 wlan0 end0; do
		if [[ -r "/sys/class/net/${iface}/address" ]]; then
			mac="$(< "/sys/class/net/${iface}/address")"
			mac="${mac//:/}"
			if [[ ${#mac} -ge 4 ]]; then
				echo "${mac: -4}" | tr '[:upper:]' '[:lower:]'
				return 0
			fi
		fi
	done

	for iface_path in /sys/class/net/*; do
		[[ -d "$iface_path" ]] || continue
		iface="$(basename "$iface_path")"
		[[ "$iface" == lo ]] && continue
		if [[ -r "${iface_path}/address" ]]; then
			mac="$(< "${iface_path}/address")"
			mac="${mac//:/}"
			if [[ ${#mac} -ge 4 ]]; then
				echo "${mac: -4}" | tr '[:upper:]' '[:lower:]'
				return 0
			fi
		fi
	done

	return 1
}
