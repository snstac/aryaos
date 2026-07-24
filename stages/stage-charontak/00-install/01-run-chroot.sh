#!/bin/bash -e
# stage-charontak 01-run-chroot.sh — Charontak CoT hub + feeder systemd wiring.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

CHARONTAK_INI="/usr/src/charontak/charontak.ini"
if [[ -f "${CHARONTAK_INI}" ]]; then
	install -v -m 0644 "${CHARONTAK_INI}" /etc/charontak.ini
fi

install -d -m 0755 /etc/systemd/system/charontak.service.d
install -v -m 0644 /usr/src/charontak/systemd/charontak.service.d/aryaos-config.conf \
	/etc/systemd/system/charontak.service.d/aryaos-config.conf

add_environment_file() {
	local unit="$1"
	local default_env="$2"
	local path="/lib/systemd/system/${unit}.service"
	[[ -f "${path}" ]] || return 0
	grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" "${path}" && return 0
	grep -qxF "EnvironmentFile=-/etc/aryaos/aryaos-config.txt" "${path}" && return 0
	if grep -qxF "EnvironmentFile=${default_env}" "${path}"; then
		local tmp
		tmp="$(mktemp)"
		awk -v site_env="EnvironmentFile=/etc/aryaos/aryaos-config.txt" \
			-v default_env="EnvironmentFile=${default_env}" '
			$0 == default_env && !inserted {
				print site_env
				inserted = 1
			}
			{ print }
		' "${path}" > "${tmp}"
		cat "${tmp}" > "${path}"
		rm -f "${tmp}"
	else
		sed --follow-symlinks -i -E \
			"/\[Service\]/a EnvironmentFile=\/etc\/aryaos\/aryaos-config.txt" \
			"${path}"
	fi
}

install_after_charontak() {
	local unit="$1"
	install -d -m 0755 "/etc/systemd/system/${unit}.service.d"
	install -v -m 0644 /usr/src/charontak/systemd/after-charontak.conf \
		"/etc/systemd/system/${unit}.service.d/after-charontak.conf"
}

for svc in adsbcot aiscot dronecot sikw00fcot lincot aircot; do
	add_environment_file "${svc}" "/etc/default/${svc}"
	install_after_charontak "${svc}"
done

# The dronecot-dronescout instance (DroneScout DS101) runs as user dronecot and
# reads MAVLink Remote ID from a USB-serial device — grant serial access.
usermod -aG dialout dronecot 2>/dev/null || true

systemctl daemon-reload || true
systemctl enable charontak.service 2>/dev/null || true
