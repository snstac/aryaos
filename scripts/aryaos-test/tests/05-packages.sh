#!/usr/bin/env bash
# 05-packages.sh — image package / artifact checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if command -v dronehone-bridge >/dev/null || dpkg -l dronehone-bridge >/dev/null 2>&1; then
	ok "dronehone-bridge package/binary present"
else
	warn "dronehone-bridge not installed (flash before dronehone-bridge merge?)"
fi

if [[ -d /var/www/html/calfire_airbases ]]; then
	warn "calfire_airbases tiles still present (removal not on this image)"
else
	ok "calfire_airbases tiles absent"
fi

if [[ -f /etc/aryaos-release || -f /etc/aryaos-version ]]; then
	ok "aryaos release/version files present"
else
	warn "aryaos release metadata missing"
fi

print_summary
