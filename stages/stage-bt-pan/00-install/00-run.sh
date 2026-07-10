#!/bin/bash -e
# 00-run.sh — copy AryaOS Bluetooth PAN payload into rootfs.
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

install -d "${ROOTFS_DIR}/usr/src/bt-pan-aryaos"
install -v -m 0755 "${SHARED_FILES}/bt-pan/aryaos-bt-ready.sh" \
	"${ROOTFS_DIR}/usr/src/bt-pan-aryaos/aryaos-bt-ready.sh"
install -v -m 0755 "${SHARED_FILES}/bt-pan/aryaos-bt-pan-nap" \
	"${ROOTFS_DIR}/usr/src/bt-pan-aryaos/aryaos-bt-pan-nap"
install -d "${ROOTFS_DIR}/usr/src/bt-pan-aryaos/systemd/system"
install -v -m 0644 "${SHARED_FILES}/bt-pan/systemd/system/aryaos-bt-ready.service" \
	"${ROOTFS_DIR}/usr/src/bt-pan-aryaos/systemd/system/aryaos-bt-ready.service"
install -v -m 0644 "${SHARED_FILES}/bt-pan/systemd/system/aryaos-bt-pan.service" \
	"${ROOTFS_DIR}/usr/src/bt-pan-aryaos/systemd/system/aryaos-bt-pan.service"
