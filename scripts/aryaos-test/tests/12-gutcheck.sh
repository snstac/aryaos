#!/usr/bin/env bash
# 12-gutcheck.sh — enabled Gutcheck capability/API/dashboard checks.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

if ! systemctl is-enabled --quiet gutcheck.service 2>/dev/null; then
	skip "Gutcheck checks skipped (service disabled)"
	print_summary
	exit 0
fi

if unit_active gutcheck; then
	ok "gutcheck active"
else
	fail "gutcheck enabled but not active"
fi

VERSION="$(dpkg-query -W -f='${Version}' gutcheck 2>/dev/null || true)"
if [[ -n "${VERSION}" ]] && dpkg --compare-versions "${VERSION}" ge 0.4.2; then
	ok "gutcheck package ${VERSION}"
else
	fail "gutcheck package ${VERSION:-missing}, expected >= 0.4.2"
fi

IDENTITY_JSON="$(curl -sS --connect-timeout 2 http://127.0.0.1:8181/.well-known/gutcheck 2>/dev/null || true)"
if python3 -c '
import json, sys
doc = json.load(sys.stdin)
assert doc["product"] == "AryaOS"
assert doc["hostname"].startswith("aryaos-")
assert "health" not in doc and "position" not in doc and "capabilities" not in doc
' <<<"${IDENTITY_JSON}" 2>/dev/null; then
	ok "GutCheck public discovery document is identity-only"
else
	fail "GutCheck public discovery document invalid"
fi

if [[ -r /run/gutcheck/neighbors.json ]]; then
	ok "GutCheck neighbor cache present"
else
	fail "GutCheck neighbor cache missing"
fi

HEALTH_CODE="$(curl -sS --connect-timeout 2 -o /dev/null -w '%{http_code}' http://127.0.0.1:8181/healthz 2>/dev/null || true)"
if [[ "${HEALTH_CODE}" == "200" ]]; then
	ok "Gutcheck health endpoint HTTP 200"
else
	fail "Gutcheck health endpoint HTTP ${HEALTH_CODE:-unavailable}"
fi

DASHBOARD_CODE="$(curl -sS --connect-timeout 2 -o /dev/null -w '%{http_code}' http://127.0.0.1:8181/ 2>/dev/null || true)"
if [[ "${DASHBOARD_CODE}" == "200" ]]; then
	ok "Gutcheck dashboard HTTP 200"
else
	fail "Gutcheck dashboard HTTP ${DASHBOARD_CODE:-unavailable}"
fi

UNAUTH_CODE="$(curl -sS --connect-timeout 2 -o /dev/null -w '%{http_code}' http://127.0.0.1:8181/api/v1/status 2>/dev/null || true)"
if [[ "${UNAUTH_CODE}" == "401" ]]; then
	ok "Gutcheck API rejects unauthenticated requests"
else
	fail "Gutcheck unauthenticated API returned HTTP ${UNAUTH_CODE:-unavailable}"
fi

API_JSON="$(sudo -n python3 - <<'PY'
import json
import time
import urllib.request

config = {}
with open("/etc/default/gutcheck", encoding="utf-8") as stream:
    for raw in stream:
        key, separator, value = raw.strip().partition("=")
        if separator:
            config[key] = value.strip().strip('"').strip("'")

headers = {"Authorization": "Bearer " + config["WEB_TOKEN"]}

def get(path):
    request = urllib.request.Request(
        "http://127.0.0.1:8181" + path, headers=headers
    )
    with urllib.request.urlopen(request, timeout=4) as response:
        return json.load(response)

payload = {}
error = None
for attempt in range(13):
    try:
        payload = {
            "status": get("/api/v1/status"),
            "entities": get("/api/v1/entities?kind=aryaos"),
        }
        error = None
        if (
            payload["status"].get("events_seen", 0) > 0
            and payload["entities"].get("items")
        ):
            break
    except (OSError, ValueError) as caught:
        error = caught
    if attempt < 12:
        time.sleep(5)
if not payload and error is not None:
    raise error
print(json.dumps(payload))
PY
)" || true

if python3 -c '
import json, sys
doc = json.load(sys.stdin)["status"]
assert doc.get("ok") is True
assert doc.get("events_seen", 0) > 0
assert doc.get("events_dropped") == 0
assert doc.get("warnings") == []
gateways = doc.get("local_gateways", [])
assert gateways
assert all(item.get("health", {}).get("state") != "disabled" for item in gateways)
for item in gateways:
    counters = item.get("counters", {})
    if item.get("app") == "dronecot-dronescout":
        assert counters.get("rx", 0) > 0
        assert counters.get("emitted", 0) > 0
' <<<"${API_JSON}" 2>/dev/null; then
	ok "Gutcheck API healthy with events and zero drops/warnings"
else
	fail "Gutcheck status API missing or unhealthy"
fi

if unit_active dronecot-dronescout; then
	if python3 -c '
import json, sys
doc = json.load(sys.stdin)["status"]
apps = {item.get("app") for item in doc.get("local_gateways", [])}
assert "dronecot-dronescout" in apps
' <<<"${API_JSON}" 2>/dev/null; then
		ok "Gutcheck displays DroneScout instance health"
	else
		fail "Gutcheck missing active DroneScout instance health"
	fi
fi

if python3 -c '
import json, sys
items = json.load(sys.stdin)["entities"].get("items", [])
assert items
machine_ids = {}
for item in items:
    uid = item.get("uid", "")
    canonical = uid[7:] if uid.startswith("aryaos-") and len(uid) == 39 else uid
    assert canonical not in machine_ids, (canonical, machine_ids[canonical], uid)
    machine_ids[canonical] = uid
entity = items[0]
assert entity.get("kind") == "aryaos"
assert isinstance(entity.get("capabilities"), list)
assert "decoding" in entity
assert "time" in entity
assert "nap" in entity
' <<<"${API_JSON}" 2>/dev/null; then
	ok "Gutcheck ingests capabilities, decoder, clock and PAN fields"
else
	fail "Gutcheck AryaOS capability entity incomplete"
fi

if python3 -c '
from importlib.resources import files
html = files("gutcheck").joinpath("static/index.html").read_text("utf-8")
for heading in ("Capabilities", "Decoding", "Clock", "PAN"):
    assert heading in html
' 2>/dev/null; then
	ok "Gutcheck dashboard displays capability field columns"
else
	fail "Gutcheck dashboard capability columns missing"
fi

ARYAOS_HEALTH_JSON="$(sudo -n /usr/local/sbin/aryaos-health --json 2>/dev/null || true)"
if python3 -c '
import json, sys
doc = json.load(sys.stdin)
apps = doc.get("apps", [])
assert apps
gutcheck = [item for item in apps if item.get("app") == "gutcheck"]
assert len(gutcheck) == 1
assert gutcheck[0].get("health", {}).get("state") == "ok"
assert gutcheck[0].get("service", {}).get("ActiveState") == "active"
assert gutcheck[0].get("service", {}).get("UnitFileState") == "enabled"
for item in apps:
    service = item.get("service", {})
    assert "UnitFileState" in service
    assert "ActiveState" in service
    if service.get("UnitFileState") == "disabled" and service.get("ActiveState") == "inactive":
        assert item.get("health", {}).get("state") == "disabled"
' <<<"${ARYAOS_HEALTH_JSON}" 2>/dev/null; then
	ok "AryaOS health includes Gutcheck and records role/service state"
else
	fail "AryaOS health role/service classification invalid"
fi

RESTARTS="$(systemctl show gutcheck -p NRestarts --value 2>/dev/null || true)"
if [[ "${RESTARTS}" == "0" ]]; then
	ok "gutcheck has not restarted"
else
	fail "gutcheck restart count ${RESTARTS:-unknown}"
fi

print_summary
