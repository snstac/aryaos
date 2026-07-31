#!/usr/bin/env python3
"""Tests for aryaos-spectrum-survey's classification logic.

These run on synthetic captures, so they need no SDR and no radio environment.
That is the point: the classifier is the part that was wrong twice during
development, and both mistakes are reproducible without hardware.

stdlib unittest, not pytest -- the CI runner does not have pytest.

Copyright Sensors & Signals LLC https://www.snstac.com/
SPDX-License-Identifier: Apache-2.0
"""

import importlib.util
import json
import os
import sys
import unittest

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-spectrum-survey")

spec = importlib.util.spec_from_loader(
    "spectrum_survey",
    importlib.machinery.SourceFileLoader("spectrum_survey", TOOL),
)
survey = importlib.util.module_from_spec(spec)
spec.loader.exec_module(survey)

NFFT = 4096
RATE = 4e6
RNG = np.random.default_rng(20260731)


def noise_frames(count=32, scale=200.0):
    return [
        (RNG.normal(0, scale, NFFT) + 1j * RNG.normal(0, scale, NFFT)).astype(np.complex64)
        for _ in range(count)
    ]


def add_tone(frames, bin_offset, amp):
    """Add a steady complex tone `bin_offset` bins away from centre."""
    n = np.arange(NFFT)
    tone = amp * np.exp(2j * np.pi * bin_offset * n / NFFT)
    return [(f + tone).astype(np.complex64) for f in frames]


def mags_from(frames):
    return np.abs(np.concatenate(frames)).astype(np.float32)


class TestClassification(unittest.TestCase):
    def analyze(self, mags, frames):
        return survey.analyze_capture(mags, frames, RATE, NFFT, np)

    def test_pure_noise_is_quiet(self):
        f = noise_frames()
        res = self.analyze(mags_from(f), f)
        self.assertFalse(res["occupied"])
        self.assertEqual(res["detection"], "none")

    def test_continuous_carrier_is_detected(self):
        """A steady tone scores ZERO excursion occupancy but must still be found.

        This is the FM-broadcast case. The first version of this tool reported
        FM broadcast as 'quiet' at 0.000% occupancy on a box where two stations
        had already been positively identified, because a continuous carrier
        raises the very median it would have to exceed.
        """
        f = add_tone(noise_frames(), bin_offset=500, amp=900.0)
        res = self.analyze(mags_from(f), f)
        self.assertGreaterEqual(res["carrier_over_noise_db"], survey.CARRIER_DB)
        self.assertTrue(res["occupied"])
        self.assertIn("continuous", res["detection"])
        # And it should report roughly where, not just that.
        self.assertAlmostEqual(
            res["carrier_offset_hz"], 500 * (RATE / NFFT), delta=RATE / NFFT * 2
        )

    def test_dc_spike_alone_is_not_a_carrier(self):
        """THE regression test.

        A direct-conversion receiver always has a large artefact at exactly its
        centre frequency. An early pass 'detected' signals at exactly 433.920,
        1090.000 and 98.500 MHz -- every one of them that artefact. If the DC
        guard is removed, this test fails and every band reads as occupied.
        """
        f = add_tone(noise_frames(), bin_offset=0, amp=5000.0)
        res = self.analyze(mags_from(f), f)
        self.assertLess(
            res["carrier_over_noise_db"], survey.CARRIER_DB,
            "DC/LO artefact was reported as a carrier -- the DC guard is not working",
        )
        self.assertNotIn("continuous", res["detection"])

    def test_bursty_traffic_is_detected(self):
        f = noise_frames()
        m = mags_from(f)
        # 2% of samples well above the floor, as a packetised emitter looks.
        idx = RNG.choice(m.size, size=int(m.size * 0.02), replace=False)
        m[idx] = float(np.median(m)) * 40.0
        res = self.analyze(m, f)
        self.assertGreaterEqual(res["occupancy_pct"], survey.OCCUPIED_PCT)
        self.assertTrue(res["occupied"])
        self.assertIn("bursty", res["detection"])

    def test_clipping_is_flagged(self):
        """Saturated samples inflate occupancy, so they must not pass silently.

        Measured on the first validation sweep: gain 40 produced peaks of +1.3,
        +2.5 and +3.0 dBFS -- above full scale -- and a 4.6% 'occupancy' that
        was an artefact of the gain setting, not of any emitter.
        """
        f = noise_frames()
        m = mags_from(f)
        m[: int(m.size * 0.05)] = 32767.0
        res = self.analyze(m, f)
        self.assertTrue(res["clipped"])
        self.assertGreater(res["clipped_pct"], 0.01)

    def test_no_iq_frames_still_returns_time_domain_stats(self):
        f = noise_frames()
        res = self.analyze(mags_from(f), [])
        self.assertEqual(res["carrier_over_noise_db"], 0.0)
        self.assertIsNone(res["carrier_offset_hz"])
        self.assertIn("occupancy_pct", res)

    def test_extra_fields_are_merged(self):
        f = noise_frames()
        res = survey.analyze_capture(
            mags_from(f), f, RATE, NFFT, np, extra={"tuned_hz": 1.0, "reads": 7}
        )
        self.assertEqual(res["tuned_hz"], 1.0)
        self.assertEqual(res["reads"], 7)


class TestBandPlan(unittest.TestCase):
    def test_band_names_unique(self):
        names = [b["name"] for b in survey.DEFAULT_BANDS]
        self.assertEqual(len(names), len(set(names)))

    def test_bands_have_required_keys(self):
        for b in survey.DEFAULT_BANDS:
            for key in ("name", "center", "span", "label"):
                self.assertIn(key, b, f"band {b.get('name')} missing {key}")

    def test_labels_make_no_detection_claim(self):
        """Labels are operator context, never an assertion about what was heard."""
        for b in survey.DEFAULT_BANDS:
            self.assertNotIn("detected", b["label"].lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)


class TestZMetaEmission(unittest.TestCase):
    """aryaos-spectrum-survey --zmeta output, validated against the REAL schema.

    The schema is vendored verbatim in scripts/vendor/ rather than approximated
    here. A hand-written stand-in would accept output the actual consumer
    rejects, which is exactly what this is meant to catch.
    """

    BAND = {
        "name": "fmbcast",
        "center": 98.0e6,
        "span": 2.0e6,
        "label": "FM broadcast (propagation check)",
    }
    SOURCE = {
        "platform_id": "aryaos-c998",
        "node_role": "EDGE",
        "producer": "aryaos-spectrum-survey",
        "sensor_id": "LimeSDR Mini",
        "sw_version": None,
    }
    # A real measurement from the test box: FM detected as a continuous carrier.
    RESULT = {
        "tuned_hz": 99.0e6,
        "noise_floor_dbfs": -45.6,
        "occupancy_pct": 0.0,
        "carrier_over_noise_db": 18.2,
        "carrier_offset_hz": -86914.0625,
        "clipped": False,
        "clipped_pct": 0.0,
        "occupied": True,
        "detection": "continuous",
    }

    def build(self, result=None):
        return survey.zmeta_event(
            self.BAND, result or self.RESULT, self.SOURCE,
            1785000000000, bytes(range(10)), 2.0,
        )

    def test_uuid7_shape(self):
        """ZMeta pins the UUID version nibble to 7; uuid4 would fail its schema."""
        ev = self.build()
        uid = ev["event"]["event_id"]
        self.assertEqual(uid[14], "7", f"not a v7 UUID: {uid}")
        self.assertIn(uid[19].lower(), "89ab", f"bad UUID variant: {uid}")

    def test_uuid7_is_time_ordered(self):
        a = survey._uuid7(1785000000000, bytes(10))
        b = survey._uuid7(1785000001000, bytes(10))
        self.assertLess(a, b, "v7 UUIDs must sort by creation time")

    def test_timestamp_is_utc_with_z(self):
        ts = self.build()["event"]["ts"]
        self.assertTrue(ts.endswith("Z"), ts)

    def test_is_observation_not_inference(self):
        """Every field is a measured fact; nothing claims what is transmitting."""
        ev = self.build()
        self.assertEqual(ev["event"]["event_type"], "OBSERVATION_EVENT")
        self.assertEqual(ev["event"]["event_subtype"], "RF")
        self.assertEqual(ev["payload"]["modality"], "RF")

    def test_no_confidence_field(self):
        """Occupancy is not a claim-strength, so confidence must not be invented."""
        self.assertNotIn("confidence", self.build())

    def test_scan_rf_vocabulary(self):
        """Payload reuses ZMeta's SCAN_RF command field names, same units."""
        f = self.build()["payload"]["features"]
        self.assertEqual(f["freq_range_hz"], [97.0e6, 99.0e6])
        self.assertEqual(f["dwell_ms"], 2000)

    def test_features_carry_no_identity(self):
        """ZMeta forbids these on an observation; we must not smuggle them in."""
        f = self.build()["payload"]["features"]
        for banned in ("track_id", "entity_class", "classification",
                       "class_name", "label", "confidence"):
            self.assertNotIn(banned, f)

    def test_clipping_surfaces_in_quality_block(self):
        clipped = dict(self.RESULT, clipped=True, clipped_pct=4.2)
        q = self.build(clipped)["payload"]["quality"]
        self.assertTrue(q["clipped"])
        self.assertFalse(q["calibrated"])

    def _schema(self):
        path = os.path.join(HERE, "vendor", "zmeta-event-1.1.0.schema.json")
        with open(path) as fh:
            return json.load(fh)

    def test_kernel_and_observation_shape_validate(self):
        """Everything except the RF power field satisfies the real schema.

        Validated by adding a placeholder power_dbm, which isolates the one
        known gap: if anything ELSE drifts out of conformance this fails.
        """
        try:
            import jsonschema
        except ImportError:
            self.skipTest("jsonschema not installed")
        ev = self.build()
        ev["payload"]["features"]["power_dbm"] = -60.0  # test-only placeholder
        jsonschema.validate(instance=ev, schema=self._schema())

    def test_power_dbm_is_deliberately_absent(self):
        """We measure dBFS, which is receiver-relative; dBm would be invented.

        On the test box the reported floor moved from -31.9 to -13.4 dBFS purely
        by changing gain. Emitting that as absolute power would be the unit
        inference ZMeta's own semantics contract forbids.

        Consequence, recorded rather than hidden: our RF observations do NOT
        satisfy ZMeta's RF feature contract, which requires power_dbm. This is a
        spec gap for uncalibrated receivers, raised upstream.
        """
        self.assertNotIn("power_dbm", self.build()["payload"]["features"])

    def test_rf_contract_gap_still_exists(self):
        """Fails when upstream relaxes power_dbm -- our cue to revisit."""
        try:
            import jsonschema
        except ImportError:
            self.skipTest("jsonschema not installed")
        with self.assertRaises(
            jsonschema.ValidationError,
            msg="ZMeta may have relaxed the RF power_dbm requirement; re-check the mapping",
        ):
            jsonschema.validate(instance=self.build(), schema=self._schema())

    def test_schema_rejects_a_malformed_event(self):
        """Proves the validation above can actually fail."""
        try:
            import jsonschema
        except ImportError:
            self.skipTest("jsonschema not installed")
        schema = self._schema()
        bad = self.build()
        bad["payload"]["features"]["power_dbm"] = -60.0
        bad["event"]["event_id"] = "not-a-uuid"
        with self.assertRaises(jsonschema.ValidationError):
            jsonschema.validate(instance=bad, schema=schema)
