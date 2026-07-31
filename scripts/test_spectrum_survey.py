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
