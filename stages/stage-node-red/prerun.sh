#!/bin/bash -e
# AryaOS prerun.sh
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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

if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi

