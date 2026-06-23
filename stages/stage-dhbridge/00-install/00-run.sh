#!/bin/bash -e
# 00-run.sh — copy AryaOS dhbridge config into rootfs.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

install -d "${ROOTFS_DIR}/usr/src/dhbridge-aryaos"
install -v -m 0644 "${SHARED_FILES}/dhbridge/dhbridge.ini" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/dhbridge.ini"
install -v -m 0755 "${SHARED_FILES}/dhbridge/aryaos-bt-ready.sh" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/aryaos-bt-ready.sh"
install -v -m 0755 "${SHARED_FILES}/dhbridge/aryaos-dhbridge-start.sh" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/aryaos-dhbridge-start.sh"
install -v -m 0755 "${SHARED_FILES}/dhbridge/aryaos-bt-pan-nap" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/aryaos-bt-pan-nap"
install -d "${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d"
install -v -m 0644 "${SHARED_FILES}/dhbridge/systemd/dhbridge.service.d/aryaos-config.conf" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-config.conf"
install -v -m 0644 "${SHARED_FILES}/dhbridge/systemd/dhbridge.service.d/aryaos-bt-ready.conf" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-bt-ready.conf"
install -v -m 0644 "${SHARED_FILES}/dhbridge/systemd/dhbridge.service.d/aryaos-hostname-broadcast.conf" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-hostname-broadcast.conf"
install -d "${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/system"
install -v -m 0644 "${SHARED_FILES}/dhbridge/systemd/system/aryaos-bt-ready.service" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/system/aryaos-bt-ready.service"
install -v -m 0644 "${SHARED_FILES}/dhbridge/systemd/system/aryaos-bt-pan.service" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/system/aryaos-bt-pan.service"
