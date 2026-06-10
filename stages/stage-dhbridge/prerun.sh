#!/bin/bash -e
# stage-dhbridge prerun — ensure rootfs from previous stage (pi-gen skips non-+x prerun.sh).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

# CI only (ARYAOS_CI_TRIM_WORK=1): pi-gen full-copies the rootfs per stage and
# 72GB hosted arm64 runners can't hold ~15 copies. Each stage needs only its
# predecessor, so drop older trees. Never set locally — breaks make skip reuse.
if [[ "${ARYAOS_CI_TRIM_WORK:-0}" == "1" && -n "${WORK_DIR:-}" ]]; then
	for d in "${WORK_DIR}"/*/rootfs; do
		[[ -d "$d" ]] || continue
		[[ "$d" -ef "${ROOTFS_DIR}" || "$d" -ef "${PREV_ROOTFS_DIR}" ]] && continue
		echo "trim-work: removing stale $d"
		rm -rf "$d"
	done
fi

if [ ! -f "${ROOTFS_DIR}/etc/os-release" ]; then
	copy_previous
fi
