#!/usr/bin/env python3
"""Remove legacy Node-RED config/control/update flows from aryaos_flows.json."""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FLOWS_PATH = REPO_ROOT / "shared_files/node-red/aryaos_flows.json"

REMOVE_FLOW_TABS = {
    "1d5c7046712ea9d2",  # Control
    "4fa67ac9ec0c7369",  # Config
    "23030b6ea0597f64",  # Update
    "f8d4ccf4360ea706",  # Sit(x)
}

REMOVE_UI_TABS = {
    "1a1f481e736717f6",  # Config
    "f61e7642f6395af5",  # Update
    "c3173234.2636e",  # OS Status
    "3883fa5a5cd96180",  # Admin (danger zone)
}

REMOVE_UI_GROUP_IDS = {
    "1890881e.83819",
    "9a96a8b1.92db78",
    "72fc319.cc425d",
    "fa4e075e1fa30638",  # Dashboard Status
    "f9087e66bb4cd9b2",  # Dashboard Control
}

DASHBOARD_FLOW_TAB = "94cf869050128770"
DASHBOARD_UI_TAB = "edc83286b603d84a"
IO_FLOW_TAB = "76732e91104cd622"

REMOVE_IO_WATCH_IDS = {
    "ba3910d8c8793f4d",  # /etc/default/adsbcot
    "1948aec0539f51d7",  # /etc/aryaos/aryaos-config.txt
    "662e281141324f13",  # tmpConf
    "65a40de620905bad",  # /run/dump1090
    "573961361f4ac80b",  # /run/dump1090-fa
    "61a91ec3d8b3f82b",  # /run/dump1090-mutability
    "1bbbc97101f3d953",  # inject aryaos-config.txt (debug)
    "5f868835544d4788",  # inject /etc/default/adsbcot (debug)
    "11af02e57d6dc86d",  # file in aryaos-config (debug)
    "4e74c03efbd3034e",  # file in adsbcot default (debug)
}

LEGACY_SERVICE_NAMES = (
    "dump1090-fa",
    "dump1090-mutability",
    "skyaware",
    "tar1090",
    "dump1090",
)

ADMIN_GROUP_ID = "a0s7nradminlinks01"
ADMIN_TEMPLATE_ID = "a0s7nradminlinks02"


def node_blob(node: dict) -> str:
    return json.dumps(node)


def should_remove_dashboard_node(node: dict) -> bool:
    if node.get("z") != DASHBOARD_FLOW_TAB:
        return False
    ntype = node.get("type", "")
    if ntype.startswith("ui_") and node.get("group") in REMOVE_UI_GROUP_IDS:
        return True
    if ntype == "exec" and "systemctl" in (node.get("command") or ""):
        return True
    if node.get("name") == "Services":
        return True
    blob = node_blob(node)
    if any(s in blob for s in LEGACY_SERVICE_NAMES):
        return True
    if "PYTAK_TLS" in blob or "tmpConf" in blob:
        return True
    return False


def add_admin_banner(flows: list[dict]) -> None:
    flows.append(
        {
            "id": ADMIN_GROUP_ID,
            "type": "ui_group",
            "name": "AryaOS admin",
            "tab": DASHBOARD_UI_TAB,
            "order": 1,
            "disp": True,
            "width": "12",
            "collapse": False,
            "className": "",
        }
    )
    flows.append(
        {
            "id": ADMIN_TEMPLATE_ID,
            "type": "ui_template",
            "z": DASHBOARD_FLOW_TAB,
            "group": ADMIN_GROUP_ID,
            "name": "Portal / Cockpit links",
            "order": 1,
            "width": 12,
            "height": 4,
            "format": (
                "<motion.div style=\"padding:8px;line-height:1.5\">"
                "<p><strong>Configuration and services</strong> are managed outside Node-RED:</p>"
                "<ul>"
                "<li><a href=\"/\" target=\"_blank\" rel=\"noopener\">HTTPS portal</a> — live status</li>"
                "<li><a href=\"/admin/\" target=\"_blank\" rel=\"noopener\">Cockpit</a> — services, Charontak, feeders</li>"
                "<li><a ng-href=\"{{'http://' + location.host + ':9080/'}}\" target=\"_blank\" rel=\"noopener\">Comitup</a> — WiFi join</li>"
                "</ul>"
                "<p style=\"margin-bottom:0;color:#666\">This dashboard keeps maps, TFR, and recorder only.</p>"
                "</motion.div>"
            ),
            "storeOutMessages": True,
            "fwdInMessages": True,
            "resendOnRefresh": True,
            "templateScope": "local",
            "className": "",
            "x": 180,
            "y": 80,
            "wires": [[]],
        }
    )


def strip_flows(flows: list[dict]) -> list[dict]:
    out: list[dict] = []
    for node in flows:
        nid = node.get("id")
        ntype = node.get("type", "")
        z = node.get("z")

        if ntype == "tab" and nid in REMOVE_FLOW_TABS:
            continue
        if ntype == "ui_tab" and nid in REMOVE_UI_TABS:
            continue
        if ntype == "ui_group" and (
            nid in REMOVE_UI_GROUP_IDS or node.get("tab") in REMOVE_UI_TABS
        ):
            continue
        if z in REMOVE_FLOW_TABS:
            continue
        if nid in REMOVE_IO_WATCH_IDS:
            continue
        if should_remove_dashboard_node(node):
            continue
        out.append(node)

    add_admin_banner(out)
    return out


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else FLOWS_PATH
    with path.open(encoding="utf-8") as fh:
        flows = json.load(fh)
    before = len(flows)
    stripped = strip_flows(flows)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(stripped, fh, indent=4)
        fh.write("\n")
    print(f"Wrote {path}: {before} -> {len(stripped)} nodes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
