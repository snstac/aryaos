#!/usr/bin/env bash
# 04-portal.sh — portal CGI HTTP + JSON validation (remote on Pi).
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

PI_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
JSON=""
HTTP_CODE=""

fetch_portal_json() {
	local url="$1"
	local tmp
	tmp="$(mktemp)"
	HTTP_CODE="$(curl -gk --max-time 10 -sS -o "${tmp}" -w '%{http_code}' "${url}" 2>/dev/null || echo "000")"
	if [[ "${HTTP_CODE}" == "200" && -s "${tmp}" ]]; then
		JSON="$(cat "${tmp}")"
		rm -f "${tmp}"
		return 0
	fi
	rm -f "${tmp}"
	return 1
}

if [[ -n "${PI_IP}" ]] && fetch_portal_json "https://${PI_IP}/cgi-bin/aryaos-portal-status"; then
	ok "portal CGI HTTPS ${PI_IP} HTTP ${HTTP_CODE}"
elif fetch_portal_json "http://127.0.0.1/cgi-bin/aryaos-portal-status"; then
	ok "portal CGI localhost HTTP ${HTTP_CODE}"
else
	fail "portal CGI unreachable (last HTTP ${HTTP_CODE})"
	print_summary
	exit 1
fi

NEIGHBORS_JSON="$(curl -gk --max-time 8 -sS https://127.0.0.1/cgi-bin/aryaos-neighbors 2>/dev/null || true)"
if python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert 'ok' in d; assert isinstance(d.get('items'), list)" <<<"${NEIGHBORS_JSON}" 2>/dev/null; then
	ok "neighbors CGI schema"
else
	fail "neighbors CGI schema invalid"
fi

VALIDATOR="${ARYAOS_VALIDATE_PORTAL:-}"
if [[ -n "${VALIDATOR}" && -f "${VALIDATOR}" ]]; then
	if echo "${JSON}" | python3 "${VALIDATOR}"; then
		ok "portal JSON full validation"
	else
		fail "portal JSON validation failed"
	fi
else
	python3 -c "
import json, sys
d = json.loads(sys.argv[1])
assert d.get('hostname')
assert 'system' in d and 'ok' in d['system']
assert 'tak_gateways' in d
g = d.get('gps') or {}
assert g.get('ok') is True
assert 'fix_type' in g and 'mode' in g
assert 'satellites_visible' in g and 'satellites_used' in g
" "${JSON}" && ok "portal JSON minimal schema" || fail "portal JSON schema"
fi

print_summary
