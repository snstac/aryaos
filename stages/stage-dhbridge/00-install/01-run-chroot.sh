#!/bin/bash -e
# 01-run-chroot.sh — AryaOS config overlay for dhbridge (package from stage-pytak manifest).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [[ -f /usr/src/dhbridge-aryaos/dhbridge.ini ]]; then
	install -v -m 0644 /usr/src/dhbridge-aryaos/dhbridge.ini /etc/dhbridge.ini
fi

if [[ -f /usr/src/dhbridge-aryaos/aryaos-bt-ready.sh ]]; then
	install -v -m 0755 /usr/src/dhbridge-aryaos/aryaos-bt-ready.sh /usr/local/sbin/aryaos-bt-ready.sh
fi

if [[ -f /usr/src/dhbridge-aryaos/aryaos-bt-pan-nap ]]; then
	install -v -m 0755 /usr/src/dhbridge-aryaos/aryaos-bt-pan-nap /usr/local/sbin/aryaos-bt-pan-nap
fi

if [[ -f /usr/src/dhbridge-aryaos/systemd/system/aryaos-bt-ready.service ]]; then
	install -v -m 0644 \
		/usr/src/dhbridge-aryaos/systemd/system/aryaos-bt-ready.service \
		/etc/systemd/system/aryaos-bt-ready.service
fi

if [[ -f /usr/src/dhbridge-aryaos/systemd/system/aryaos-bt-pan.service ]]; then
	install -v -m 0644 \
		/usr/src/dhbridge-aryaos/systemd/system/aryaos-bt-pan.service \
		/etc/systemd/system/aryaos-bt-pan.service
fi

if [[ -f /usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-config.conf ]]; then
	install -d -m 0755 /etc/systemd/system/dhbridge.service.d
	install -v -m 0644 \
		/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-config.conf \
		/etc/systemd/system/dhbridge.service.d/aryaos-config.conf
fi

if [[ -f /usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-bt-ready.conf ]]; then
	install -d -m 0755 /etc/systemd/system/dhbridge.service.d
	install -v -m 0644 \
		/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-bt-ready.conf \
		/etc/systemd/system/dhbridge.service.d/aryaos-bt-ready.conf
fi

systemctl daemon-reload || true
systemctl enable aryaos-bt-ready.service 2>/dev/null || true
systemctl enable aryaos-bt-pan.service 2>/dev/null || true
systemctl enable dhbridge.service 2>/dev/null || true
