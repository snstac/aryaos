#!/usr/bin/env python3
"""AryaOS neighbor-cache parsing tests (stdlib-only for CI)."""

import importlib.machinery
import importlib.util
import os
import unittest


HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-neighbord")

spec = importlib.util.spec_from_loader(
    "aryaos_neighbord",
    importlib.machinery.SourceFileLoader("aryaos_neighbord", TOOL),
)
neighbord = importlib.util.module_from_spec(spec)
spec.loader.exec_module(neighbord)


class BeaconV5TestCase(unittest.TestCase):
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
