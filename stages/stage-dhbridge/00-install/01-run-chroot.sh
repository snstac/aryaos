#!/bin/bash -e
# 01-run-chroot.sh — AryaOS config overlay for dhbridge (package from stage-pytak manifest).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [[ -f /usr/src/dhbridge-aryaos/dhbridge.ini ]]; then
	install -v -m 0644 /usr/src/dhbridge-aryaos/dhbridge.ini /etc/dhbridge.ini
fi

if [[ -f /usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-config.conf ]]; then
	install -d -m 0755 /etc/systemd/system/dhbridge.service.d
	install -v -m 0644 \
		/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-config.conf \
		/etc/systemd/system/dhbridge.service.d/aryaos-config.conf
fi

systemctl daemon-reload || true
systemctl enable dhbridge.service 2>/dev/null || true
