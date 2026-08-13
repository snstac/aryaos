#!/bin/bash -e
# 00-run.sh — copy COTBridge config into rootfs for stage-cotbridge.
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

install -d "${ROOTFS_DIR}/usr/src/cotbridge"
install -v -m 0644 "${SHARED_FILES}/cotbridge/cotbridge.ini" "${ROOTFS_DIR}/usr/src/cotbridge/cotbridge.ini"
install -d "${ROOTFS_DIR}/usr/src/cotbridge/systemd/cotbridge.service.d"
install -v -m 0644 "${SHARED_FILES}/cotbridge/systemd/cotbridge.service.d/aryaos-config.conf" \
	"${ROOTFS_DIR}/usr/src/cotbridge/systemd/cotbridge.service.d/aryaos-config.conf"
install -v -m 0644 "${SHARED_FILES}/cotbridge/systemd/after-cotbridge.conf" \
	"${ROOTFS_DIR}/usr/src/cotbridge/systemd/after-cotbridge.conf"
install -d "${ROOTFS_DIR}/usr/src/cotbridge/systemd/sikw00fcot.service.d"
install -v -m 0644 \
	"${SHARED_FILES}/cotbridge/systemd/sikw00fcot.service.d/aryaos-config.conf" \
	"${ROOTFS_DIR}/usr/src/cotbridge/systemd/sikw00fcot.service.d/aryaos-config.conf"
