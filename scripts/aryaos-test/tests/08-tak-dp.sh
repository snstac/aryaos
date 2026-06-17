#!/usr/bin/env bash
# 08-tak-dp.sh — TAK data package upload endpoint and Cockpit UI checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if unit_active aryaos-tak-dp-importd; then
	ok "aryaos-tak-dp-importd active"
else
	fail "aryaos-tak-dp-importd not active"
fi

if [[ -S /run/aryaos/tak-dp-import.sock ]]; then
	ok "TAK DP import socket present"
else
	fail "TAK DP import socket missing"
fi

GET_BODY="$(curl -gk --max-time 8 -sS https://127.0.0.1/cgi-bin/aryaos-tak-dp-upload 2>/dev/null || true)"
if python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert d.get("ok") is True; assert ".zip" in d.get("accept", [])' <<<"${GET_BODY}" 2>/dev/null; then
	ok "TAK DP upload endpoint capability JSON"
else
	fail "TAK DP upload endpoint capability JSON invalid"
fi

BAD_BODY="$(printf notazip | curl -gk --max-time 10 -sS -F package=@- https://127.0.0.1/cgi-bin/aryaos-tak-dp-upload 2>/dev/null || true)"
if python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert d.get("ok") is False; assert "ZIP" in d.get("error", "")' <<<"${BAD_BODY}" 2>/dev/null; then
	ok "TAK DP upload rejects invalid ZIP"
else
	fail "TAK DP upload invalid ZIP rejection failed"
fi

if grep -q 'id="card-dp"' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'btn-dp-upload' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null; then
	ok "Cockpit AryaOS TAK DP UI installed"
else
	fail "Cockpit AryaOS TAK DP UI missing"
fi

if curl -gk --max-time 8 -sS https://127.0.0.1/ 2>/dev/null | grep -q 'aos-tak-dp-form'; then
	ok "portal TAK DP upload form installed"
else
	fail "portal TAK DP upload form missing"
fi

print_summary
