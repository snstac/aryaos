#!/bin/bash -e
# stage-charontak prerun — ensure rootfs from previous stage (pi-gen skips non-+x prerun.sh).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

if [ ! -f "${ROOTFS_DIR}/etc/os-release" ]; then
	copy_previous
fi

if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "$0")/../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES
