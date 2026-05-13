#!/bin/bash -e
# Remove upstream stage2 EXPORT_IMAGE so pi-gen continues into AryaOS custom stages.
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../../.." && pwd)

remove_export_image() {
	local f="${1}/stage2/EXPORT_IMAGE"
	if [[ -f "${f}" ]] && [[ -w "$(dirname "${f}")" ]]; then
		rm -f "${f}"
		echo "Removed ${f}"
	fi
}

# PI_GEN_ROOT: directory that contains stage0/ (local ./pi-gen or CI pi-gen-src).
if [[ -n "${PI_GEN_ROOT:-}" ]]; then
	remove_export_image "${PI_GEN_ROOT}"
fi

remove_export_image "${REPO_ROOT}/pi-gen"
remove_export_image "${REPO_ROOT}/pi-gen-src"

# Official pi-gen Docker image keeps the toolchain at /pi-gen.
remove_export_image "/pi-gen"

# pi-gen build cwd is often the toolchain root; common layouts:
remove_export_image "$(pwd)"
remove_export_image "$(pwd)/.."
