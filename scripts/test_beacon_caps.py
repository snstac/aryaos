#!/usr/bin/env python3
"""Beacon capability reporting.

stdlib unittest, not pytest -- the CI runner has no pytest.

Copyright Sensors & Signals LLC https://www.snstac.com/
SPDX-License-Identifier: Apache-2.0
"""

import importlib.machinery
import importlib.util
import os
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-cot-detail")

spec = importlib.util.spec_from_loader(
    "cot_detail", importlib.machinery.SourceFileLoader("cot_detail", TOOL)
)
beacon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(beacon)


class SdrCapeTestCase(unittest.TestCase):
    """A box with an SDR and no decoder chosen reports `sdr`, not three claims.

    It used to beacon adsb, ais AND acars, each available=true. That reads as
    three capabilities and is one radio -- and it overstates even that, because
    which of them decodes anything is decided by the antenna, which the box
    cannot see. Measured this session: the same software and SDR went from 0
    usable ADS-B messages on an indoor whip to 5173 on an outdoor antenna.
    """

    def setUp(self):
        self._originals = {
            name: getattr(beacon, name)
            for name in ("_config", "_detected_caps", "_service_state", "_wifi_adapter")
        }

    def tearDown(self):
        for name, value in self._originals.items():
            setattr(beacon, name, value)

    def _caps(self, active, detected, active_units=()):
        beacon._config = lambda key: ",".join(active) if key == "ARYAOS_CAPABILITIES" else ""
        beacon._detected_caps = lambda: set(detected)
        beacon._service_state = lambda unit: "active" if unit in active_units else "inactive"
        beacon._wifi_adapter = lambda: ""
        return {c["key"]: c for c in beacon._capabilities()}

    def test_idle_sdr_collapses_to_one_cape(self):
        caps = self._caps(active=[], detected=["adsb", "ais", "acars"])
        self.assertIn("sdr", caps)
        for specific in ("adsb", "ais", "acars"):
            self.assertNotIn(specific, caps, f"{specific} should be folded into sdr")

    def test_sdr_cape_is_available_but_never_active(self):
        caps = self._caps(active=[], detected=["adsb"])
        self.assertEqual(caps["sdr"]["available"], "true")
        self.assertEqual(caps["sdr"]["enabled"], "false")
        self.assertEqual(caps["sdr"]["active"], "false")

    def test_enabled_decoder_is_named(self):
        """Once an operator chooses one, report it by name."""
        caps = self._caps(active=["acars"], detected=["adsb", "ais", "acars"])
        self.assertIn("acars", caps)
        self.assertEqual(caps["acars"]["enabled"], "true")

    def test_enabled_decoder_does_not_suppress_the_others(self):
        """The unchosen ones still collapse, so the radio is still advertised."""
        caps = self._caps(active=["acars"], detected=["adsb", "ais", "acars"])
        self.assertIn("sdr", caps)
        self.assertNotIn("adsb", caps)

    def test_non_sdr_capabilities_are_untouched(self):
        """ble-rid has its own radio and must keep reporting itself."""
        caps = self._caps(active=[], detected=["ble-rid", "adsb"])
        self.assertIn("ble-rid", caps)
        self.assertIn("sdr", caps)

    def test_no_sdr_means_no_sdr_cape(self):
        caps = self._caps(active=[], detected=["ble-rid"])
        self.assertNotIn("sdr", caps)

    def test_sensor_text_names_what_is_possible(self):
        caps = self._caps(active=[], detected=["adsb", "acars"])
        sensor = caps["sdr"]["sensor"]
        self.assertIn("adsb", sensor)
        self.assertIn("acars", sensor)

    def test_running_gateway_is_proof_capability_is_available(self):
        caps = self._caps(active=["dji"], detected=[], active_units=["dronecot-dji"])
        self.assertEqual(caps["dji"]["active"], "true")
        self.assertEqual(caps["dji"]["available"], "true")


class CapabilityCacheTestCase(unittest.TestCase):
    def test_empty_cache_is_a_valid_hardware_snapshot(self):
        original_cache = beacon.CAP_CACHE
        original_run = beacon._run
        try:
            with tempfile.TemporaryDirectory() as directory:
                beacon.CAP_CACHE = os.path.join(directory, "capabilities-detected")
                open(beacon.CAP_CACHE, "w", encoding="utf-8").close()

                def unexpected_scan(*_args, **_kwargs):
                    self.fail("an existing empty cache must not launch a hardware scan")

                beacon._run = unexpected_scan
                self.assertEqual(beacon._detected_caps(), set())
        finally:
            beacon.CAP_CACHE = original_cache
            beacon._run = original_run

    def test_unprivileged_beacon_does_not_launch_hardware_scan(self):
        if os.geteuid() == 0:
            self.skipTest("test requires the normal unprivileged CI user")
        original_cache = beacon.CAP_CACHE
        original_scan = beacon.CAP_SCAN
        original_run = beacon._run
        try:
            with tempfile.TemporaryDirectory() as directory:
                beacon.CAP_CACHE = os.path.join(directory, "missing-cache")
                beacon.CAP_SCAN = os.path.join(directory, "scanner")
                open(beacon.CAP_SCAN, "w", encoding="utf-8").close()

                def unexpected_scan(*_args, **_kwargs):
                    self.fail("an unprivileged beacon must not launch hardware discovery")

                beacon._run = unexpected_scan
                self.assertEqual(beacon._detected_caps(), set())
        finally:
            beacon.CAP_CACHE = original_cache
            beacon.CAP_SCAN = original_scan
            beacon._run = original_run


if __name__ == "__main__":
    unittest.main(verbosity=2)
