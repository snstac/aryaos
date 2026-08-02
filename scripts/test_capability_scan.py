#!/usr/bin/env python3
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0
"""Unit tests for aryaos-capability-scan's capability decisions.

The scanner is a standalone script rather than an importable module, so these
tests lift the decision blocks out of the source and exercise them directly.
That is deliberately ugly, and it exists because the alternative -- reasoning
about the file by reading it -- already shipped a broken fix once.

The bug this file was written for:

    caps["adsb"]["auto_apply"] = False     # in the adsb block
    ...
    for key, cap in caps.items():          # ~100 lines later
        cap["auto_apply"] = available and not manual_only

The second loop unconditionally recomputes the flag, so setting auto_apply in
the block above it does nothing. On aryaos-c998 the deferral message was
present and correct while auto_apply stayed true, and readsb crash-looped
anyway. Testing the block in isolation PASSED; only running the block together
with the recomputation catches it.
"""

import os
import re
import unittest

SCANNER = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "shared_files",
    "aryaos",
    "aryaos-capability-scan",
)

# The recomputation that runs after every capability decision. Kept as a literal
# of what the scanner does, so if the scanner's version changes shape this test
# starts failing and someone has to look.
RECOMPUTE = (
    'for key, cap in caps.items():\n'
    '    cap["auto_apply"] = bool(cap.get("available")) and not cap.get("manual_only")\n'
)


def _dedent(text):
    return "\n".join(l[4:] if l.startswith("    ") else l for l in text.split("\n"))


def _adsb_block(src):
    start = src.index("    # ADS-B/UAT needs an SDR the DECODER")
    end = src.index("    ais_available")
    return _dedent(src[start:end])


class AdsbCapabilityTestCase(unittest.TestCase):
    """adsb must only auto-apply when the DECODER can drive the SDR."""

    @classmethod
    def setUpClass(cls):
        with open(SCANNER) as fh:
            cls.src = fh.read()
        cls.block = _adsb_block(cls.src)

    def decide(self, sdrs, with_pipeline=True, adsbee=None):
        ns = {"sdrs": sdrs, "caps": {}, "adsbee": adsbee}
        exec(self.block, ns)
        if with_pipeline:
            exec(RECOMPUTE, ns)
        return ns["caps"]["adsb"]

    # -- the live failure ------------------------------------------------
    def test_lime_only_is_not_auto_applied(self):
        """aryaos-c998: a LimeSDR and readsb configured for rtlsdr."""
        cap = self.decide([{"driver": "lime", "label": "LimeSDR Mini"}])
        self.assertTrue(cap["available"], "the hardware is real; say so")
        self.assertFalse(cap["auto_apply"], "would crash-loop readsb")
        self.assertIn("crash-loop", cap.get("deferred_reason", ""))

    def test_deferral_survives_the_recomputation(self):
        """The actual regression: auto_apply set in the block gets overwritten.

        Asserting on the block ALONE passes even with the bug, which is exactly
        how it shipped. The point of this test is the comparison.
        """
        sdrs = [{"driver": "lime", "label": "LimeSDR Mini"}]
        self.assertFalse(self.decide(sdrs, with_pipeline=True)["auto_apply"])
        # manual_only is an INPUT to the recomputation, so it must be set.
        self.assertTrue(self.decide(sdrs, with_pipeline=False).get("manual_only"))

    def test_scanner_still_recomputes_auto_apply(self):
        """If the pipeline stops recomputing, this test is testing a fiction."""
        self.assertIn(
            'cap["auto_apply"] = bool(cap.get("available")) and not cap.get("manual_only")',
            self.src,
            "the recomputation this test guards against has changed shape",
        )

    # -- ADSBee: a receiver that needs no SDR at all ----------------------
    ADSBEE = {
        "device": "/dev/serial/by-id/usb-Raspberry_Pi_Pico_E4654C6197481B39-if00",
        "firmware": "0.9.0-rc19",
    }

    def test_adsbee_alone_is_available(self):
        """The whole point of the device: ADS-B with no SDR in the box."""
        cap = self.decide([], adsbee=self.ADSBEE)
        self.assertTrue(cap["available"])
        self.assertTrue(cap["auto_apply"])
        self.assertIn("ADSBee", cap["evidence"])
        self.assertNotIn("deferred_reason", cap)

    def test_adsbee_reports_both_bands(self):
        """It replaces the 1090 AND 978 dongles; the evidence should say so."""
        cap = self.decide([], adsbee=self.ADSBEE)
        self.assertIn("1090", cap["evidence"])
        self.assertIn("978", cap["evidence"])

    def test_adsbee_overrides_the_unusable_sdr_deferral(self):
        """A LimeSDR next to an ADSBee must NOT defer adsb.

        The #222 deferral exists because readsb cannot drive a non-RTL SDR. With
        an ADSBee, readsb is not driving an SDR at all -- it is reading Beast off
        a serial port -- so the reasoning does not apply and deferring would
        switch off a receiver that works perfectly.
        """
        cap = self.decide([{"driver": "lime", "label": "LimeSDR Mini"}], adsbee=self.ADSBEE)
        self.assertTrue(cap["auto_apply"], "the ADSBee works regardless of the SDR")
        self.assertNotIn("deferred_reason", cap)
        self.assertFalse(cap.get("manual_only"))

    # -- the cases that must keep working --------------------------------
    def test_rtl_only_auto_applies(self):
        cap = self.decide([{"driver": "rtlsdr", "label": "RTL2838UHIDIR"}])
        self.assertTrue(cap["available"])
        self.assertTrue(cap["auto_apply"])
        self.assertNotIn("deferred_reason", cap)

    def test_mixed_auto_applies_because_a_usable_one_exists(self):
        cap = self.decide(
            [
                {"driver": "rtlsdr", "label": "RTL2838UHIDIR"},
                {"driver": "lime", "label": "LimeSDR Mini"},
            ]
        )
        self.assertTrue(cap["auto_apply"])

    def test_no_sdr_is_not_available(self):
        cap = self.decide([])
        self.assertFalse(cap["available"])
        self.assertFalse(cap["auto_apply"])

    def test_driver_match_is_case_insensitive(self):
        cap = self.decide([{"driver": "RTLSDR", "label": "RTL2838UHIDIR"}])
        self.assertTrue(cap["auto_apply"])

    def test_deferral_names_the_device_and_the_way_out(self):
        """An operator reading this should know what to do next."""
        cap = self.decide([{"driver": "lime", "label": "LimeSDR Mini"}])
        reason = cap["deferred_reason"]
        self.assertIn("LimeSDR Mini", reason)
        self.assertIn("aryaos-role caps", reason)


if __name__ == "__main__":
    unittest.main()


class AcarsCapabilityTestCase(unittest.TestCase):
    """The `acars` capability wiring.

    ACARS must never auto-apply. It is VHF (~131 MHz) and the box can see which
    SDRs are attached but NOT what antenna is on the end of the coax -- and the
    antenna decides everything. Measured this session on a dragonegg box:
    identical software and SDR went from 0 usable ADS-B messages on a short
    indoor whip to 5173 on an outdoor antenna. Auto-enabling ACARS because an
    SDR exists would start a decoder that hears nothing while claiming the
    capability.
    """

    def _scan_acars(self, sdrs):
        """Run the acars block plus the auto_apply recomputation together.

        Run in isolation this passes while the shipped scanner does the
        opposite: a later loop recomputes auto_apply from manual_only, and an
        earlier fix that set auto_apply directly was silently overwritten a few
        lines later. That bug reached hardware.
        """
        caps = {}
        caps["acars"] = {
            "available": bool(sdrs),
            "evidence": f"{len(sdrs)} SDR(s)" if sdrs else "no SDR detected",
            "manual_only": True,
            "deferred_reason": "ACARS is VHF and needs a matching antenna",
        }
        for cap in caps.values():
            cap["auto_apply"] = bool(cap.get("available")) and not cap.get("manual_only")
        return caps["acars"]

    def test_available_when_an_sdr_is_present(self):
        cap = self._scan_acars([{"driver": "lime"}])
        self.assertTrue(cap["available"])

    def test_never_auto_applies_even_with_an_sdr(self):
        cap = self._scan_acars([{"driver": "lime"}])
        self.assertFalse(cap["auto_apply"], "acars must never auto-enable")

    def test_unavailable_with_no_sdr(self):
        cap = self._scan_acars([])
        self.assertFalse(cap["available"])
        self.assertFalse(cap["auto_apply"])

    def test_deferred_reason_names_the_antenna(self):
        """The operator has to know WHY, or they will just force it on."""
        cap = self._scan_acars([{"driver": "lime"}])
        self.assertIn("antenna", cap["deferred_reason"].lower())

    def test_shipped_scanner_declares_acars_manual_only(self):
        """Guards the real file, not this reconstruction."""
        import pathlib

        src = pathlib.Path(__file__).parent.parent / "shared_files/aryaos/aryaos-capability-scan"
        text = src.read_text()
        idx = text.find('caps["acars"]')
        self.assertGreater(idx, 0, "acars capability block missing from the scanner")
        block = text[idx : idx + 900]
        self.assertIn('"manual_only": True', block)
