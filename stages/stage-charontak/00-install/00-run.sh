#!/bin/bash -e
# 00-run.sh — copy Charontak config into rootfs for stage-charontak.
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

install -d "${ROOTFS_DIR}/usr/src/charontak"
install -v -m 0644 "${SHARED_FILES}/charontak/charontak.ini" "${ROOTFS_DIR}/usr/src/charontak/charontak.ini"
install -d "${ROOTFS_DIR}/usr/src/charontak/systemd/charontak.service.d"
install -v -m 0644 "${SHARED_FILES}/charontak/systemd/charontak.service.d/aryaos-config.conf" \
	"${ROOTFS_DIR}/usr/src/charontak/systemd/charontak.service.d/aryaos-config.conf"
install -v -m 0644 "${SHARED_FILES}/charontak/systemd/after-charontak.conf" \
	"${ROOTFS_DIR}/usr/src/charontak/systemd/after-charontak.conf"
