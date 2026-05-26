#!/bin/bash -e
# stage-lincot 00-run.sh — AryaOS LINCOT defaults into rootfs.
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

install -d "${ROOTFS_DIR}/usr/src/lincot"
install -v -m 0644 "${SHARED_FILES}/lincot/lincot.default" "${ROOTFS_DIR}/usr/src/lincot/lincot.default"
