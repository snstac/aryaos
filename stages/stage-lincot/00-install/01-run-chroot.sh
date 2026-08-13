#!/bin/bash -e
# stage-lincot 01-run-chroot.sh — apply AryaOS LINCOT config after .deb from stage-pytak.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [[ -f /usr/src/lincot/lincot.default ]]; then
	install -v -m 0644 /usr/src/lincot/lincot.default /etc/default/lincot
fi

install -d /etc/systemd/system/lincot.service.d
install -v -m 0644 \
	/usr/src/lincot/systemd/lincot.service.d/aryaos-config.conf \
	/etc/systemd/system/lincot.service.d/aryaos-config.conf

systemctl daemon-reload || true
systemctl enable lincot.service 2>/dev/null || true
