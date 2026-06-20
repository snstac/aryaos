#!/usr/bin/env python3
# Validate aryaos-portal-status JSON from lab Pi integration tests.
# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

import json
import sys
from typing import Any

REQUIRED_TOP = (
    "hostname",
    "fqdn",
    "primary_ip",
    "uptime",
    "gps",
    "radios",
    "tak_gateways",
    "system",
)

EXPECTED_GATEWAY_IDS = (
    "charontak",
    "lincot",
    "adsbcot",
    "aiscot",
    "dronecot",
    "sikw00fcot",
)


def validate(data: dict[str, Any]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    ok_lines: list[str] = []

    for key in REQUIRED_TOP:
        if key not in data:
            errors.append(f"missing top-level key: {key}")

    if not data.get("hostname"):
        errors.append("hostname empty")

    system = data.get("system")
    if not isinstance(system, dict) or "ok" not in system:
        errors.append("system.ok missing")
    else:
        ok_lines.append("portal system block present")

    gps = data.get("gps")
    if not isinstance(gps, dict):
        errors.append("gps block missing")
    elif gps.get("ok"):
        ok_lines.append("gps ok")
    else:
        ok_lines.append("gps present (no fix — warn tier on host)")

    radios = data.get("radios")
    if not isinstance(radios, dict) or "devices" not in radios:
        errors.append("radios.devices missing")
    else:
        ok_lines.append(f"radios devices={len(radios.get('devices') or [])}")

    tac = data.get("tak_gateways")
    if not isinstance(tac, dict) or "items" not in tac:
        errors.append("tak_gateways.items missing")
    else:
        ids = {item.get("id") for item in tac.get("items") or [] if isinstance(item, dict)}
        for gid in EXPECTED_GATEWAY_IDS:
            if gid not in ids:
                errors.append(f"tak_gateways missing id: {gid}")
            else:
                ok_lines.append(f"tak_gateways id={gid}")

    return errors, ok_lines


def main() -> int:
    raw = sys.stdin.read() if len(sys.argv) < 2 else open(sys.argv[1], encoding="utf-8").read()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"FAIL invalid JSON: {exc}", file=sys.stderr)
        return 1

    errors, ok_lines = validate(data)
    for line in ok_lines:
        print(f"OK   {line}")
    for err in errors:
        print(f"FAIL {err}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
