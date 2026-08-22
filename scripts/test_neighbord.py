#!/usr/bin/env python3
"""AryaOS neighbor-cache parsing tests (stdlib-only for CI)."""

import importlib.machinery
import importlib.util
import os
import unittest
from unittest import mock


HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-neighbord")

spec = importlib.util.spec_from_loader(
    "aryaos_neighbord",
    importlib.machinery.SourceFileLoader("aryaos_neighbord", TOOL),
)
neighbord = importlib.util.module_from_spec(spec)
spec.loader.exec_module(neighbord)


class BeaconV5TestCase(unittest.TestCase):
    def test_plural_multicast_addresses_override_legacy_single_address(self):
        with (
            mock.patch.object(
                neighbord,
                "MULTICAST_LOCAL_ADDRS",
                "10.41.0.1, 169.254.2.3 10.41.0.1",
            ),
            mock.patch.object(neighbord, "MULTICAST_LOCAL_ADDR", "192.0.2.10"),
        ):
            self.assertEqual(
                neighbord._multicast_local_addrs(),
                ("10.41.0.1", "169.254.2.3"),
            )

    def test_fallback_beacon_uid_matches_lincot_machine_id(self):
        machine_id = "0e4474225f2843a4b8d3ac3e74a7fdb9"
        with mock.patch.object(neighbord, "_read", return_value=machine_id):
            self.assertEqual(neighbord._uid(), machine_id)

    def test_fallback_beacon_has_namespaced_uid_without_machine_id(self):
        with (
            mock.patch.object(neighbord, "_read", return_value=""),
            mock.patch.object(
                neighbord.socket, "gethostname", return_value="aryaos-test.local"
            ),
        ):
            self.assertEqual(neighbord._uid(), "aryaos-aryaos-test")

    def test_preserves_capability_and_runtime_health_fields(self):
        event = b"""<event uid="aryaos-test" type="a-f-G-E-S" time="now">
          <point lat="1" lon="2"/><detail><__aryaos version="5">
          <host name="aryaos-test"/><system temp_c="42.0"/>
          <time synced="yes" daemon="chrony" tdoa_ready="false"/>
          <nap service="active" iface="pan0" up="true" clients="1"/>
          <capabilities><capability key="wifi-rid" active="true"
            available="true" enabled="true" sensor="Atheros AR9271"/>
          </capabilities>
          <decoding summary="decoders: active rid 2.5/min">
            <source source="rid" state="active" rate_min="2.5" tracked="2"/>
          </decoding></__aryaos></detail></event>"""

        parsed = neighbord._parse_event(event, "192.0.2.10")
        self.assertIsNotNone(parsed)
        _name, item = parsed
        self.assertEqual(item["capabilities"][0]["available"], "true")
        self.assertEqual(item["capabilities"][0]["sensor"], "Atheros AR9271")
        self.assertEqual(item["time"]["daemon"], "chrony")
        self.assertEqual(item["nap"]["clients"], "1")
        self.assertEqual(item["decoding"]["sources"][0]["rate_min"], "2.5")


if __name__ == "__main__":
    unittest.main(verbosity=2)
