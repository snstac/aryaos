#!/bin/bash -e
# 01-run-chroot.sh — build and install dronehone-bridge .deb, enable systemd.
# pi-gen runs this via: on_chroot < 01-run-chroot.sh (do not wrap in on_chroot here).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -e
export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-recommends \
	debhelper \
	dh-python \
	pybuild-plugin-pyproject \
	python3-all \
	python3-setuptools \
	bluez \
	|| true

if [[ -d /usr/src/dronehone-bridge ]]; then
	cd /usr/src/dronehone-bridge
	dpkg-buildpackage -us -uc -b -d || dpkg-buildpackage -us -uc -b
	deb=$(ls -1 /usr/src/dronehone-bridge_*.deb 2>/dev/null | head -1)
	if [[ -n "${deb}" && -f "${deb}" ]]; then
		dpkg -i "${deb}" || apt-get install -fy -y
	fi
fi

if [[ -f /usr/src/dronehone-bridge-aryaos/dronehone-bridge.ini ]]; then
	install -v -m 0644 /usr/src/dronehone-bridge-aryaos/dronehone-bridge.ini /etc/dronehone-bridge.ini
fi

if [[ -f /usr/src/dronehone-bridge-aryaos/systemd/dronehone-bridge.service.d/aryaos-config.conf ]]; then
	install -d -m 0755 /etc/systemd/system/dronehone-bridge.service.d
	install -v -m 0644 \
		/usr/src/dronehone-bridge-aryaos/systemd/dronehone-bridge.service.d/aryaos-config.conf \
		/etc/systemd/system/dronehone-bridge.service.d/aryaos-config.conf
fi

systemctl daemon-reload || true
systemctl enable dronehone-bridge.service 2>/dev/null || true
