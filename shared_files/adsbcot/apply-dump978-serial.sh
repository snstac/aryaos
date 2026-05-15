#!/usr/bin/env bash
# Apply ARYAOS_UAT_RTL_SERIAL from /etc/aryaos/aryaos-config.txt into /etc/default/dump978-fa
# before dump978-fa starts (systemd ExecStartPre, runs as root).
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

CFG="/etc/aryaos/aryaos-config.txt"
DF="/etc/default/dump978-fa"

[[ -r "$CFG" && -f "$DF" ]] || exit 0

set +u
# shellcheck disable=SC1090
. "$CFG"
set -u

: "${ARYAOS_UAT_RTL_SERIAL:=}"
[[ -n "${ARYAOS_UAT_RTL_SERIAL}" ]] || exit 0

exec python3 - "$DF" "${ARYAOS_UAT_RTL_SERIAL}" <<'PY'
import re
import sys

path, sn = sys.argv[1], sys.argv[2]
if not re.fullmatch(r"[A-Za-z0-9_.:+-]{1,128}", sn):
    sys.exit(0)
try:
    text = open(path, "r", encoding="utf-8", errors="replace").read()
except OSError:
    sys.exit(0)
new, n = re.subn(
    r"(driver=rtlsdr,serial=)[^ \t\n#]+",
    lambda m: m.group(1) + sn,
    text,
    count=1,
)
if n:
    try:
        open(path, "w", encoding="utf-8").write(new)
    except OSError:
        sys.exit(1)
PY
