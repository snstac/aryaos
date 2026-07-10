#!/usr/bin/env bash
# 05-packages.sh — image package / artifact checks (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if command -v dhbridge >/dev/null || dpkg -s dhbridge >/dev/null 2>&1; then
	warn "dhbridge present (private package; expected absent on public images)"
else
	ok "dhbridge absent (private package)"
fi

if dpkg-query -W -f='${Status}' aryaos-overlay 2>/dev/null | grep -q "install ok installed"; then
	ok "aryaos-overlay package installed"
else
	warn "aryaos-overlay package not installed (legacy pre-package image?)"
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
