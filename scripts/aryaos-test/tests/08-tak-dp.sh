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

if unit_active aryaos-neighbord; then
	if sudo systemctl restart aryaos-neighbord.service && [[ -S /run/aryaos/tak-dp-import.sock ]]; then
		ok "neighbor restart preserves TAK DP import socket"
	else
		fail "neighbor restart removed TAK DP import socket"
	fi
else
	skip "aryaos-neighbord inactive; socket preservation check skipped"
fi

GET_BODY="$(curl -gk --max-time 8 -sS https://127.0.0.1/cgi-bin/aryaos-tak-dp-upload 2>/dev/null || true)"
if python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); s=d.get("enrollment_status") or {}; assert d.get("ok") is True; assert ".zip" in d.get("accept", []); assert d.get("accept_enrollment_url") is True; assert isinstance(s.get("configured"), bool); assert isinstance(s.get("tls"), dict); assert "import_service_ready" in s' <<<"${GET_BODY}" 2>/dev/null; then
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

BAD_ENROLL_BODY="$(curl -gk --max-time 10 -sS -F enrollment_url=not-a-tak-url https://127.0.0.1/cgi-bin/aryaos-tak-dp-upload 2>/dev/null || true)"
if python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert d.get("ok") is False; assert "tak://" in d.get("error", "")' <<<"${BAD_ENROLL_BODY}" 2>/dev/null; then
	ok "TAK enrollment URL rejects invalid URL"
else
	fail "TAK enrollment URL invalid rejection failed"
fi

if grep -q 'id="card-dp"' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'tak-enrollment-table' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'dp-enrollment-url' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'btn-dp-upload' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null \
	&& grep -q 'btn-enrollment-import' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null \
	&& grep -q 'refreshTakEnrollmentStatus' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null; then
	ok "Cockpit AryaOS TAK connection UI installed"
else
	fail "Cockpit AryaOS TAK connection UI missing"
fi

PORTAL_BODY="$(curl -gk --max-time 8 -sS https://127.0.0.1/ 2>/dev/null || true)"
if grep -q 'Configure TAK in Cockpit' <<<"${PORTAL_BODY}" && ! grep -q 'aos-tak-dp-form' <<<"${PORTAL_BODY}"; then
	ok "portal TAK configuration is Cockpit-only"
else
	fail "portal TAK configuration should be read-only"
fi

print_summary
