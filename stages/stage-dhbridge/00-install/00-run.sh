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
install -d "${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d"
install -v -m 0644 "${SHARED_FILES}/dhbridge/systemd/dhbridge.service.d/aryaos-config.conf" \
	"${ROOTFS_DIR}/usr/src/dhbridge-aryaos/systemd/dhbridge.service.d/aryaos-config.conf"
