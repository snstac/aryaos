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

DETAIL_XML="$(/usr/local/sbin/aryaos-cot-detail 2>/dev/null || true)"
if python3 -c "import sys,xml.etree.ElementTree as ET; root=ET.fromstring(sys.stdin.read()); assert root.tag == '__aryaos'; assert root.find('host') is not None" <<<"${DETAIL_XML}" 2>/dev/null; then
	ok "AryaOS CoT detail uses __aryaos tag"
else
	fail "AryaOS CoT detail tag invalid"
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

if grep -ilqx 'LimeSDR Mini' /sys/bus/usb/devices/*/product >/dev/null 2>&1; then
	if python3 -c "
import json, sys
d = json.loads(sys.argv[1])
lime = next(x for x in d['radios']['devices'] if x.get('kind') == 'usb_sdr' and 'limesdr' in x.get('label', '').lower())
assert lime.get('frequency_range_mhz') == {'min': 10, 'max': 3500}
" "${JSON}"; then
		ok "portal identifies LimeSDR Mini and its 10–3,500 MHz coverage"
	else
		fail "portal is missing LimeSDR Mini identity or coverage"
	fi
fi

if [[ -x /usr/bin/vcgencmd ]]; then
	if python3 -c "
import json, sys
d = json.loads(sys.argv[1])
t = (d.get('system') or {}).get('throttle')
assert isinstance(t, dict)
assert isinstance(t.get('raw'), int)
assert t.get('state') in ('ok', 'warn', 'bad')
" "${JSON}"; then
		ok "portal power telemetry available inside lighttpd sandbox"
	else
		fail "portal power telemetry unavailable inside lighttpd sandbox"
	fi
else
	skip "vcgencmd absent; Raspberry Pi power telemetry not applicable"
fi

COCKPIT_BRANDING="$(curl -gk --max-time 8 -sS https://127.0.0.1/admin/cockpit/static/branding.css 2>/dev/null || true)"
COCKPIT_MARK="$(curl -gk --max-time 8 -sS https://127.0.0.1/admin/cockpit/static/mark-aryaos-rev.svg 2>/dev/null || true)"
if grep -q 'url("mark-aryaos-rev.svg")' <<<"${COCKPIT_BRANDING}" \
	&& grep -qi '#e4610f' <<<"${COCKPIT_BRANDING}" \
	&& grep -q '<svg' <<<"${COCKPIT_MARK}" \
	&& grep -qi '#E4610F' <<<"${COCKPIT_MARK}"; then
	ok "Cockpit serves canonical AryaOS reverse mark and Signal Orange branding"
else
	fail "Cockpit AryaOS branding asset unavailable or non-canonical"
fi

print_summary
