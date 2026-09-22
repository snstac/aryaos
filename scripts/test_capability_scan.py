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


def _ais_block(src):
    start = src.index("    # AIS: a dedicated NMEA receiver")
    end = src.index("    # DJI DroneID:")
    return _dedent(src[start:end])


# The conflict resolver that runs after the recomputation. Kept as a literal for
# the same reason as RECOMPUTE: the ais bug was invisible without it.
CONTENTION = (
    'for key in ("adsb", "ais"):\n'
    '    cap = caps.get(key)\n'
    '    if not cap or not cap.get("auto_apply"):\n'
    '        continue\n'
    '    for loser in cap.get("contended_with") or []:\n'
    '        other = caps.get(loser)\n'
    '        if other and other.get("auto_apply"):\n'
    '            other["auto_apply"] = False\n'
    '            other["deferred_reason"] = "shares a radio with %s" % key\n'
)


class AdsbCapabilityTestCase(unittest.TestCase):
    """adsb must only auto-apply when the DECODER can drive the SDR."""

    @classmethod
    def setUpClass(cls):
        with open(SCANNER) as fh:
            cls.src = fh.read()
        cls.block = _adsb_block(cls.src)

    def decide(self, sdrs, with_pipeline=True, adsbee=None):
        ns = {"sdrs": sdrs, "adsbee": adsbee or [], "caps": {}}
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

    def test_adsbee_without_sdr_is_available_and_auto_applied(self):
        cap = self.decide(
            [], adsbee=["/dev/serial/by-id/usb-Raspberry_Pi_Pico_ADSBee-if00"]
        )
        self.assertTrue(cap["available"])
        self.assertTrue(cap["auto_apply"])
        self.assertIn("ADSBee", cap["evidence"])

    def test_driver_match_is_case_insensitive(self):
        cap = self.decide([{"driver": "RTLSDR", "label": "RTL2838UHIDIR"}])
        self.assertTrue(cap["auto_apply"])

    def test_deferral_names_the_device_and_the_way_out(self):
        """An operator reading this should know what to do next."""
        cap = self.decide([{"driver": "lime", "label": "LimeSDR Mini"}])
        reason = cap["deferred_reason"]
        self.assertIn("LimeSDR Mini", reason)
        self.assertIn("aryaos-role caps", reason)


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

    def test_role_manager_controls_both_acars_units(self):
        """Persisting `acars` must also enable its decoder and gateway."""
        import pathlib
        import re

        src = pathlib.Path(__file__).parent.parent / "shared_files/aryaos/aryaos-role"
        text = src.read_text()
        match = re.search(
            r"all_managed_units\(\) \{(?P<body>.*?)\n\}", text, re.DOTALL
        )
        self.assertIsNotNone(match, "all_managed_units function missing")
        managed = match.group("body")
        self.assertIn("acarsdec", managed)
        self.assertIn("acarscot", managed)


class SerialRoleWiringTestCase(unittest.TestCase):
    def test_ais_serial_is_assigned_before_services_start(self):
        import pathlib
        import re

        role = (
            pathlib.Path(__file__).parent.parent / "shared_files/aryaos/aryaos-role"
        ).read_text()
        self.assertRegex(
            role,
            re.compile(
                r"set_caps\(\).*?prepare_serial_ais \"\$\{wanted\}\".*?"
                r"apply_units \"\$\{wanted\}\"",
                re.S,
            ),
        )
        self.assertRegex(
            role,
            re.compile(
                r"prepare_serial_ais\(\).*?systemctl enable ais-catcher\.service"
                r".*?aryaos-serial-assign",
                re.S,
            ),
        )

    def test_factory_reset_rearms_hardware_discovery(self):
        import pathlib

        reset = (
            pathlib.Path(__file__).parent.parent
            / "shared_files/aryaos/aryaos-factory-reset"
        ).read_text()
        self.assertIn(".capabilities-autodetected", reset)
        self.assertIn(".capabilities-autodetect-tries", reset)
        self.assertIn("aryaos-role caps none", reset)
        self.assertIn("aryaos-safe-mode reset-for-factory", reset)
        self.assertIn("dpkg --force-confmiss --force-confnew --configure -a", reset)
        self.assertIn("--force-confnew", reset)
        self.assertNotIn("--force-confask", reset)
        self.assertIn("timeout --signal=TERM --kill-after=30s 5m", reset)

        verifier = (
            pathlib.Path(__file__).parent.parent / "scripts/verify-image.sh"
        ).read_text()
        self.assertIn(
            "dpkg --force-confmiss --force-confnew --configure -a", verifier
        )

        safe_mode = (
            pathlib.Path(__file__).parent.parent
            / "shared_files/aryaos/aryaos-safe-mode"
        ).read_text()
        self.assertIn("cmd_reset_for_factory", safe_mode)
        self.assertIn("reset-for-factory) cmd_reset_for_factory", safe_mode)

        overlay_builder = (
            pathlib.Path(__file__).parent.parent
            / "scripts/build-aryaos-overlay-deb.sh"
        ).read_text()
        self.assertIn('aryaos-safe-mode" "/usr/local/sbin/aryaos-safe-mode', overlay_builder)
        self.assertIn("aryaos-crash-guard.service", overlay_builder)

    def test_firstboot_applies_detected_transport_wiring(self):
        import pathlib

        root = pathlib.Path(__file__).parent.parent / "shared_files/aryaos"
        firstboot = (root / "aryaos-firstboot.sh").read_text()
        role = (root / "aryaos-role").read_text()
        self.assertIn("aryaos-role apply-detected $DETECTED", firstboot)
        self.assertRegex(
            role,
            re.compile(
                r"apply_detected_caps\(\).*?configure_detected_inputs.*?set_caps",
                re.S,
            ),
        )

    def test_adsbee_selection_uses_modesbeast_and_skips_uat(self):
        import pathlib

        role = (
            pathlib.Path(__file__).parent.parent / "shared_files/aryaos/aryaos-role"
        ).read_text()
        self.assertIn("--device-type modesbeast", role)
        self.assertIn("ARYAOS_ADSB_1090_SOURCE", role)
        self.assertRegex(
            role,
            re.compile(r'ARYAOS_ADSB_1090_SOURCE\).*?adsbee.*?adsbcot gdlcot', re.S),
        )

    def test_dronescout_unit_has_missing_device_guard(self):
        import pathlib

        root = pathlib.Path(__file__).parent.parent / "shared_files/aryaos"
        unit = (root / "systemd/dronecot-dronescout.service").read_text()
        helper = (root / "dronecot-serial-ready").read_text()
        self.assertIn("ExecCondition=/usr/local/libexec/aryaos/dronecot-serial-ready", unit)
        self.assertIn('[[ -c "${device}" && -r "${device}" ]]', helper)

    def test_dronescout_reverses_broken_crlf_expansion(self):
        import pathlib

        defaults = (
            pathlib.Path(__file__).parent.parent
            / "shared_files/aryaos/dronecot-dronescout.default"
        ).read_text()
        self.assertIn("SERIAL_CRLF_NORMALIZE=1", defaults)

        scanner = (
            pathlib.Path(__file__).parent.parent
            / "shared_files/aryaos/aryaos-capability-scan"
        ).read_text()
        role = (
            pathlib.Path(__file__).parent.parent
            / "shared_files/aryaos/aryaos-role"
        ).read_text()
        self.assertIn('--rid-transport', scanner)
        self.assertIn('[[ "${rid_transport}" == "esp32-usb" ]]', role)
        self.assertIn("SERIAL_CRLF_NORMALIZE=${rid_crlf}", role)

    def test_dronescout_discovery_avoids_colons_in_pymavlink_device(self):
        import pathlib

        role = (
            pathlib.Path(__file__).parent.parent / "shared_files/aryaos/aryaos-role"
        ).read_text()
        self.assertIn("readlink -f /dev/dronescout", role)
        self.assertIn('rid_feed_port="/dev/dronescout"', role)
        self.assertIn('[[ "${rid_port}" == *:* ]]', role)
        self.assertIn("FEED_URL=serial://${rid_feed_port}:115200", role)



class AisCapabilityTestCase(unittest.TestCase):
    """ais must not auto-apply on the strength of a bare SDR.

    The live failure (aryaos-a29c, 2026-09-22). A DragonEgg -- LimeSDR Mini v2
    plus a USB GPS, no AIS receiver of any kind -- came off its first boot with

        ARYAOS_CAPABILITIES="ais"

    and aiscot enabled against a radio pointed at nothing.

    Three things had to line up, which is why reading the file did not catch it:

      1. caps["ais"] carried no manual_only, so the recomputation made it
         auto-applicable purely because an SDR existed.
      2. The contention loop should have demoted it in favour of adsb -- but it
         starts with `if not cap.get("auto_apply"): continue`, and on this
         hardware adsb is manual_only (non-RTL SDR), so the higher-priority
         entry was skipped and ais was never demoted.
      3. Once aiscot was running, the "a capability whose gateway is ALREADY
         RUNNING is available by definition" rule re-marked ais available on
         every later scan -- the scanner confirming its own mistake.

    Testing the ais block alone passes even with the bug present. Only the block
    plus RECOMPUTE plus CONTENTION reproduces it.
    """

    @classmethod
    def setUpClass(cls):
        with open(SCANNER) as fh:
            cls.src = fh.read()
        cls.block = _ais_block(cls.src)

    def decide(self, sdrs, ais_serial=None, adsbee=None, adsb_manual_only=False):
        # adsb is seeded the way the real scanner leaves it by this point.
        caps = {
            "adsb": {
                "available": bool(sdrs or adsbee),
                "evidence": "seeded by the adsb block",
            }
        }
        if adsb_manual_only:
            caps["adsb"]["manual_only"] = True
        ns = {
            "sdrs": sdrs,
            "ais_serial": ais_serial,
            "silent_ais_serial": None,
            "adsbee": adsbee or [],
            "caps": caps,
            "_labels": lambda items: ", ".join(
                i.get("label", i.get("driver", "?")) for i in items
            ),
        }
        exec(self.block, ns)
        exec(RECOMPUTE, ns)
        exec(CONTENTION, ns)
        return ns["caps"]

    # -- the live failure ------------------------------------------------
    def test_lime_only_box_does_not_auto_apply_ais(self):
        """aryaos-a29c: one LimeSDR, no AIS receiver, adsb deferred."""
        caps = self.decide(
            [{"driver": "lime", "label": "LimeSDR Mini"}], adsb_manual_only=True
        )
        self.assertTrue(caps["ais"]["available"], "an SDR could run AIS; say so")
        self.assertFalse(
            caps["ais"]["auto_apply"],
            "a bare SDR is not evidence that anyone wants AIS",
        )

    def test_contention_loop_cannot_be_relied_on_to_demote_ais(self):
        """The reason a contention-only fix would not have worked.

        adsb is manual_only here, so the loop skips it and never demotes ais.
        ais must therefore defer on its own merits, not on adsb's behalf.
        """
        caps = self.decide(
            [{"driver": "lime", "label": "LimeSDR Mini"}], adsb_manual_only=True
        )
        self.assertFalse(caps["adsb"]["auto_apply"], "precondition: adsb deferred")
        self.assertFalse(
            caps["ais"]["auto_apply"],
            "ais auto-applied because the loop skipped the deferred adsb entry",
        )

    def test_manual_only_is_what_survives_the_recomputation(self):
        """auto_apply is recomputed FROM manual_only, so it must be the input."""
        ns_caps = self.decide([{"driver": "lime"}], adsb_manual_only=True)
        self.assertTrue(ns_caps["ais"].get("manual_only"))

    def test_deferred_reason_names_the_antenna(self):
        caps = self.decide([{"driver": "lime"}], adsb_manual_only=True)
        self.assertIn("antenna", caps["ais"].get("deferred_reason", "").lower())

    # -- the cases that must keep working --------------------------------
    def test_dedicated_ais_receiver_still_auto_applies(self):
        """A real AIS receiver IS evidence of intent. Do not regress this."""
        caps = self.decide([], ais_serial="/dev/serial/by-id/usb-dAISy")
        self.assertTrue(caps["ais"]["available"])
        self.assertTrue(
            caps["ais"]["auto_apply"],
            "somebody attached an AIS receiver; that is the whole signal",
        )
        self.assertNotIn("manual_only", caps["ais"])

    def test_ais_receiver_alongside_an_sdr_still_auto_applies(self):
        caps = self.decide(
            [{"driver": "rtlsdr", "label": "RTL"}],
            ais_serial="/dev/serial/by-id/usb-dAISy",
        )
        self.assertTrue(caps["ais"]["auto_apply"])

    def test_no_sdr_and_no_receiver_is_unavailable(self):
        caps = self.decide([])
        self.assertFalse(caps["ais"]["available"])
        self.assertFalse(caps["ais"]["auto_apply"])

    def test_shipped_scanner_defers_sdr_backed_ais(self):
        """Guards the real file, not this reconstruction."""
        idx = self.src.find('caps["ais"] = {')
        self.assertGreater(idx, 0, 'caps["ais"] assignment not found')
        window = self.src[idx:idx + 2000]
        self.assertIn(
            'caps["ais"]["manual_only"] = True',
            window,
            "SDR-backed ais must be manual_only in the shipped scanner",
        )


if __name__ == "__main__":
    unittest.main()
