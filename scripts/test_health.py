#!/usr/bin/env python3
"""Unit tests for role-aware AryaOS gateway health aggregation."""

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


TOOL = Path(__file__).parents[1] / "shared_files/aryaos/aryaos-health"
LOADER = importlib.machinery.SourceFileLoader("aryaos_health", str(TOOL))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
HEALTH = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(HEALTH)


class GatewayHealthTestCase(unittest.TestCase):
    def test_disabled_optional_gateway_does_not_degrade_box(self):
        with tempfile.TemporaryDirectory() as root:
            item = HEALTH.load(
                "aiscot",
                100,
                root=root,
                state={
                    "LoadState": "loaded",
                    "UnitFileState": "disabled",
                    "ActiveState": "inactive",
                },
            )

        self.assertEqual(item["health"]["state"], "disabled")
        self.assertEqual(
            HEALTH.overall_health(
                [item, {"health": {"state": "ok"}}]
            ),
            "ok",
        )

    def test_enabled_inactive_gateway_is_a_fault(self):
        with tempfile.TemporaryDirectory() as root:
            item = HEALTH.load(
                "aiscot",
                100,
                root=root,
                state={
                    "LoadState": "loaded",
                    "UnitFileState": "enabled",
                    "ActiveState": "inactive",
                },
            )

        self.assertEqual(item["health"]["state"], "fault")
        self.assertEqual(HEALTH.overall_health([item]), "fault")

    def test_hardware_condition_skip_is_visible_but_not_a_box_fault(self):
        with tempfile.TemporaryDirectory() as root:
            item = HEALTH.load(
                "dronecot-dronescout",
                100,
                root=root,
                state={
                    "LoadState": "loaded",
                    "UnitFileState": "enabled",
                    "ActiveState": "inactive",
                    "Result": "exec-condition",
                },
            )

        self.assertEqual(item["health"]["state"], "unavailable")
        self.assertEqual(
            item["health"]["detail"], "required hardware is not present"
        )
        self.assertEqual(
            HEALTH.overall_health([item, {"health": {"state": "ok"}}]),
            "ok",
        )

    def test_inventory_contains_every_guaranteed_gateway(self):
        self.assertEqual(
            HEALTH.APPS,
            (
                "cotbridge", "gpscot", "lincot", "gutcheck", "adsbcot",
                "aiscot", "acarscot", "aprscot", "gdlcot",
                "dronecot-dji", "dronecot-wifi", "dronecot-ble",
                "dronecot-dronescout", "sikw00fcot", "sapientcot",
            ),
        )

    def test_active_gateway_without_contract_remains_unknown(self):
        with tempfile.TemporaryDirectory() as root:
            item = HEALTH.load(
                "adsbcot",
                100,
                root=root,
                state={
                    "LoadState": "loaded",
                    "UnitFileState": "enabled",
                    "ActiveState": "active",
                },
            )

        self.assertEqual(item["health"]["state"], "unknown")
        self.assertEqual(
            item["health"]["detail"], "service active; no runtime status"
        )
        self.assertEqual(HEALTH.overall_health([item]), "degraded")

    def test_active_gutcheck_uses_its_systemd_contract(self):
        with tempfile.TemporaryDirectory() as root:
            item = HEALTH.load(
                "gutcheck",
                100,
                root=root,
                state={
                    "LoadState": "loaded",
                    "UnitFileState": "enabled",
                    "ActiveState": "active",
                    "NRestarts": 0,
                },
            )

        self.assertEqual(item["health"], {"state": "ok", "detail": "service active"})
        self.assertEqual(HEALTH.overall_health([item]), "ok")

    def test_runtime_contract_carries_systemd_evidence(self):
        state = {
            "LoadState": "loaded",
            "UnitFileState": "enabled",
            "ActiveState": "active",
            "NRestarts": 0,
        }
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "gpscot" / "status.json"
            path.parent.mkdir()
            path.write_text(
                json.dumps(
                    {
                        "wall_t": 95,
                        "health": {"state": "ok"},
                        "counters": {"emitted": 10},
                    }
                )
            )
            item = HEALTH.load("gpscot", 100, root=root, state=state)

        self.assertEqual(item["app"], "gpscot")
        self.assertEqual(item["age_s"], 5)
        self.assertEqual(item["service"], state)
        self.assertEqual(item["health"]["state"], "ok")

    def test_fresh_document_cannot_mask_inactive_enabled_service(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "gpscot" / "status.json"
            path.parent.mkdir()
            path.write_text(
                json.dumps(
                    {"wall_t": 99, "health": {"state": "ok"}}
                )
            )
            item = HEALTH.load(
                "gpscot",
                100,
                root=root,
                state={
                    "LoadState": "loaded",
                    "UnitFileState": "enabled",
                    "ActiveState": "inactive",
                },
            )

        self.assertEqual(item["health"]["state"], "fault")
        self.assertEqual(item["health"]["detail"], "enabled service inactive")


if __name__ == "__main__":
    unittest.main(verbosity=2)
