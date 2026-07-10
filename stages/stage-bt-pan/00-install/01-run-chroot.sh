#!/bin/bash -e
# 01-run-chroot.sh — install the AryaOS Bluetooth PAN helpers and services.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [[ -f /usr/src/bt-pan-aryaos/aryaos-bt-ready.sh ]]; then
	install -v -m 0755 /usr/src/bt-pan-aryaos/aryaos-bt-ready.sh /usr/local/sbin/aryaos-bt-ready.sh
fi

if [[ -f /usr/src/bt-pan-aryaos/aryaos-bt-pan-nap ]]; then
	install -v -m 0755 /usr/src/bt-pan-aryaos/aryaos-bt-pan-nap /usr/local/sbin/aryaos-bt-pan-nap
fi

if [[ -f /usr/src/bt-pan-aryaos/systemd/system/aryaos-bt-ready.service ]]; then
	install -v -m 0644 \
		/usr/src/bt-pan-aryaos/systemd/system/aryaos-bt-ready.service \
		/etc/systemd/system/aryaos-bt-ready.service
fi

if [[ -f /usr/src/bt-pan-aryaos/systemd/system/aryaos-bt-pan.service ]]; then
	install -v -m 0644 \
		/usr/src/bt-pan-aryaos/systemd/system/aryaos-bt-pan.service \
		/etc/systemd/system/aryaos-bt-pan.service
fi

systemctl daemon-reload || true
systemctl enable aryaos-bt-ready.service 2>/dev/null || true
systemctl enable aryaos-bt-pan.service 2>/dev/null || true
