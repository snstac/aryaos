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

TAK_STATUS_JSON="$(sudo -n /usr/local/sbin/aryaos-tak-dp-import --status 2>/dev/null || true)"
if ! python3 -c 'import json,sys; json.load(sys.stdin)' <<<"${TAK_STATUS_JSON}" 2>/dev/null; then
	fail "TAK enrollment status is not valid JSON"
elif python3 -c 'import json,sys; raise SystemExit(not json.load(sys.stdin)["enrollment_status"]["configured"])' \
	<<<"${TAK_STATUS_JSON}" 2>/dev/null; then
	ok "TAK Server enrollment configured"
	if runtime_detail="$(sudo -n python3 - 2>&1 <<'PY'
import json
from pathlib import Path

status = json.loads(Path("/run/cotbridge/status.json").read_text())
lane = status.get("lanes", {}).get("site-output", {})
health = status.get("health", {}).get("state")
output = lane.get("output", {})
if health != "ok" or output.get("state") != "connected":
    raise SystemExit(
        f"health={health or 'missing'} output={output.get('state') or 'missing'} "
        f"detail={output.get('detail') or status.get('health', {}).get('detail') or 'none'}"
    )
print(f"health={health} output={output['state']} tx={status.get('counters', {}).get('tx', 0)}")
PY
)"; then
		ok "configured TAK site output connected (${runtime_detail})"
	else
		fail "configured TAK site output unhealthy (${runtime_detail})"
	fi
else
	skip "TAK Server enrollment not configured"
fi

if unit_active gutcheck; then
	if sudo systemctl restart gutcheck.service && [[ -S /run/aryaos/tak-dp-import.sock ]]; then
		ok "neighbor restart preserves TAK DP import socket"
	else
		fail "neighbor restart removed TAK DP import socket"
	fi
else
	skip "gutcheck inactive; socket preservation check skipped"
fi

# The unauthenticated /cgi-bin/aryaos-tak-dp-upload endpoint was REMOVED on
# purpose. It was reachable pre-auth from the LAN and from the onboarding
# hotspot, so anyone who could see the box could import a TAK data package or an
# enrollment URL -- a CoT/TAK takeover. Importing now runs through the
# authenticated Cockpit superuser backend aryaos-tak-dp-import.
#
# These checks used to assert that endpoint WORKED, and so reported four
# failures on every healthy box: they were testing for the presence of a fixed
# vulnerability. Four permanent red lines in a suite is worse than no check at
# all, because it teaches people the suite is noise.
#
# Inverted: the security property is that the endpoint is NOT reachable.
DP_CGI_CODE="$(curl -gk --max-time 8 -sS -o /dev/null -w '%{http_code}' \
	https://127.0.0.1/cgi-bin/aryaos-tak-dp-upload 2>/dev/null || echo 000)"
if [[ "${DP_CGI_CODE}" =~ ^(403|404)$ ]]; then
	ok "unauthenticated TAK DP upload CGI not reachable (HTTP ${DP_CGI_CODE})"
else
	fail "unauthenticated TAK DP upload CGI answered HTTP ${DP_CGI_CODE} — pre-auth TAK import is a CoT takeover path"
fi

if [[ ! -e /usr/lib/cgi-bin/aryaos-tak-dp-upload ]]; then
	ok "TAK DP upload CGI absent from the image"
else
	fail "TAK DP upload CGI is installed — it must not be"
fi

# A POST must not mutate anything either; a 403/404 is the whole point.
DP_POST_CODE="$(printf notazip | curl -gk --max-time 10 -sS -o /dev/null -w '%{http_code}' \
	-F package=@- https://127.0.0.1/cgi-bin/aryaos-tak-dp-upload 2>/dev/null || echo 000)"
if [[ "${DP_POST_CODE}" =~ ^(403|404)$ ]]; then
	ok "unauthenticated TAK DP upload POST refused (HTTP ${DP_POST_CODE})"
else
	fail "unauthenticated TAK DP upload POST answered HTTP ${DP_POST_CODE}"
fi

# ...and the authenticated replacement must actually be there, or the feature is
# simply gone rather than moved.
if [[ -x /usr/local/sbin/aryaos-tak-dp-import ]]; then
	ok "authenticated TAK DP import backend present"
else
	fail "authenticated TAK DP import backend missing — the feature moved nowhere"
fi

if grep -q 'id="card-dp"' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'tak-enrollment-table' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'dp-enrollment-url' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'id="card-neighbors"' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'neighbors-table' /usr/share/cockpit/aryaos/index.html 2>/dev/null \
	&& grep -q 'btn-dp-upload' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null \
	&& grep -q 'btn-enrollment-import' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null \
	&& grep -q 'refreshTakEnrollmentStatus' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null \
	&& grep -q 'refreshNeighbors' /usr/share/cockpit/aryaos/aryaos.js 2>/dev/null; then
	ok "Cockpit AryaOS TAK connection and neighbor UI installed"
else
	fail "Cockpit AryaOS TAK connection or neighbor UI missing"
fi

PORTAL_BODY="$(curl -gk --max-time 8 -sS https://127.0.0.1/ 2>/dev/null || true)"
# The security property: the portal is unauthenticated, so it must carry no
# mutating TAK form. That is the part that matters and it is asserted on its own.
if ! grep -q 'aos-tak-dp-form' <<<"${PORTAL_BODY}"; then
	ok "portal carries no unauthenticated TAK configuration form"
else
	fail "portal has a TAK configuration form — the portal is unauthenticated"
fi

# Separate, and only a warning: having removed the form, the portal should still
# tell an operator where configuration moved to. Right now it says nothing, which
# is a dead end rather than a vulnerability.
if grep -qi 'tak.*cockpit\|configure tak' <<<"${PORTAL_BODY}"; then
	ok "portal points at Cockpit for TAK configuration"
else
	warn "portal does not say where to configure TAK (form correctly absent, but no pointer)"
fi

print_summary
