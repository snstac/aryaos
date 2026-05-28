#!/bin/bash -e
# 00-run.sh — copy dronehone-bridge source and AryaOS config into rootfs.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../../.." && pwd)

if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="${REPO_ROOT}/shared_files"
	fi
fi
export SHARED_FILES

install -d "${ROOTFS_DIR}/usr/src/dronehone-bridge"
rsync -a --delete \
	--exclude '.git' \
	--exclude '__pycache__' \
	--exclude '*.pyc' \
	--exclude 'debian/.debhelper' \
	--exclude 'debian/dronehone-bridge' \
	--exclude 'debian/files' \
	--exclude 'debian/*.debhelper.log' \
	--exclude 'debian/*.substvars' \
	"${REPO_ROOT}/dronehone-bridge/" "${ROOTFS_DIR}/usr/src/dronehone-bridge/"

install -d "${ROOTFS_DIR}/usr/src/dronehone-bridge-aryaos"
install -v -m 0644 "${SHARED_FILES}/dronehone-bridge/dronehone-bridge.ini" \
	"${ROOTFS_DIR}/usr/src/dronehone-bridge-aryaos/dronehone-bridge.ini"
install -d "${ROOTFS_DIR}/usr/src/dronehone-bridge-aryaos/systemd/dronehone-bridge.service.d"
install -v -m 0644 "${SHARED_FILES}/dronehone-bridge/systemd/dronehone-bridge.service.d/aryaos-config.conf" \
	"${ROOTFS_DIR}/usr/src/dronehone-bridge-aryaos/systemd/dronehone-bridge.service.d/aryaos-config.conf"
