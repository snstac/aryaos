#!/usr/bin/env python3
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0
"""Unit tests for the aryaos-adsbee-lockdown radio lockdown.

The lockdown script runs as ExecStartPre of readsb.service. It must quiet an
ADSBee's onboard radios (Wi-Fi AP, Wi-Fi station, Ethernet, public aggregator
feeds) without ever writing a setting that is already correct, and without
ever blocking readsb reception on a bad device.

desired_settings() and satisfied() are ported unchanged from the
adsbee-receiver branch (PR #248). They are tested against recorded console
transcripts: AT+SETTINGS?DUMP output from a real ADSBee in its stock state
and in its post-lockdown state. The transcript files in scripts/fixtures/
reconstruct the documented stock firmware format (see the PR body for what
was and was not captured on hardware).
"""

import importlib.machinery
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared_files" / "adsbcot" / "aryaos-adsbee-lockdown"
STOCK_DUMP = ROOT / "scripts" / "fixtures" / "adsbee-settings-dump-stock.txt"
LOCKED_DUMP = ROOT / "scripts" / "fixtures" / "adsbee-settings-dump-locked.txt"


def _load_lockdown():
    loader = importlib.machinery.SourceFileLoader(
        "aryaos_adsbee_lockdown", str(SCRIPT)
    )
    spec = importlib.util.spec_from_loader("aryaos_adsbee_lockdown", loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


LOCKDOWN = _load_lockdown()


def _dump(path):
    return LOCKDOWN.parse_settings_dump(path.read_text(encoding="utf-8"))


class ParseSettingsDumpTest(unittest.TestCase):
    def test_stock_transcript_parses_expected_keys(self):
        current = _dump(STOCK_DUMP)
        self.assertEqual(
            current["WIFI_AP"], "AT+WIFI_AP=1,ADSBee1090-9A3B7C,yummyflowers,1"
        )
        self.assertEqual(current["WIFI_STA"], "AT+WIFI_STA=0,,")
        self.assertEqual(current["ETHERNET"], "AT+ETHERNET=1")
        self.assertEqual(current["ESP32_ENABLE"], "AT+ESP32_ENABLE=1")
        self.assertEqual(current["LOG_LEVEL"], "AT+LOG_LEVEL=INFO")
        self.assertEqual(
            current["PROTOCOL_OUT:CONSOLE"], "AT+PROTOCOL_OUT=CONSOLE,NONE"
        )
        self.assertEqual(
            current["PROTOCOL_OUT:COMMS_UART"], "AT+PROTOCOL_OUT=COMMS_UART,NONE"
        )
        # Per-interface keys must not overwrite each other.
        self.assertEqual(
            current["FEED:6"], "AT+FEED=6,feed.whereplane.xyz,0,1,RAW"
        )
        self.assertEqual(current["FEED:9"], "AT+FEED=9,feed.adsb.fi,0,1,RAW")

    def test_non_setting_lines_are_skipped(self):
        # Header chatter from the console must not leak into the settings map.
        current = _dump(STOCK_DUMP)
        self.assertNotIn("ADSBee 1090U settings dump", str(current.values()))
        self.assertNotIn("banner", {k for k in current if k == "banner"})


class DesiredSettingsTest(unittest.TestCase):
    def test_lockdown_targets(self):
        current = _dump(STOCK_DUMP)
        wanted = LOCKDOWN.desired_settings(current, disable_radio=True)
        self.assertEqual(wanted["WIFI_STA"], "AT+WIFI_STA=0,,")
        self.assertEqual(wanted["ETHERNET"], "AT+ETHERNET=0")
        self.assertEqual(
            wanted["WIFI_AP"], "AT+WIFI_AP=0,ADSBee1090-9A3B7C,yummyflowers,1"
        )
        self.assertEqual(wanted["ESP32_ENABLE"], "AT+ESP32_ENABLE=1")
        self.assertEqual(
            wanted["PROTOCOL_OUT:CONSOLE"], "AT+PROTOCOL_OUT=CONSOLE,BEAST"
        )
        self.assertEqual(
            wanted["PROTOCOL_OUT:COMMS_UART"], "AT+PROTOCOL_OUT=COMMS_UART,NONE"
        )
        self.assertEqual(wanted["LOG_LEVEL"], "AT+LOG_LEVEL=SILENT")
        for index in range(10):
            self.assertEqual(
                wanted[f"FEED:{index}"], f"AT+FEED={index},,0,0,NONE"
            )

    def test_wifi_ap_keeps_existing_ssid_and_flips_only_enable(self):
        current = _dump(STOCK_DUMP)
        wanted = LOCKDOWN.desired_settings(current, disable_radio=True)
        # The stock SSID, password and channel survive; only the enable flag
        # moves to 0.
        args = wanted["WIFI_AP"].partition("=")[2].split(",")
        self.assertEqual(args[0], "0")
        self.assertEqual(args[1], "ADSBee1090-9A3B7C")
        self.assertEqual(args[2], "yummyflowers")
        self.assertEqual(args[3], "1")

    def test_wifi_ap_fallback_when_setting_absent(self):
        wanted = LOCKDOWN.desired_settings({}, disable_radio=True)
        self.assertEqual(wanted["WIFI_AP"], "AT+WIFI_AP=0,ADSBee,aryaos415,1")

    def test_radio_on_still_pins_esp32_and_clears_feeds(self):
        current = _dump(STOCK_DUMP)
        wanted = LOCKDOWN.desired_settings(current, disable_radio=False)
        self.assertNotIn("WIFI_STA", wanted)
        self.assertNotIn("WIFI_AP", wanted)
        self.assertNotIn("ETHERNET", wanted)
        # OPSEC items are independent of the radio switch.
        self.assertEqual(wanted["ESP32_ENABLE"], "AT+ESP32_ENABLE=1")
        self.assertEqual(wanted["FEED:6"], "AT+FEED=6,,0,0,NONE")
        self.assertEqual(
            wanted["PROTOCOL_OUT:CONSOLE"], "AT+PROTOCOL_OUT=CONSOLE,BEAST"
        )


class DiffSettingsTest(unittest.TestCase):
    def test_stock_device_writes_only_the_differences(self):
        current = _dump(STOCK_DUMP)
        wanted = LOCKDOWN.desired_settings(current, disable_radio=True)
        changes = LOCKDOWN.diff_settings(current, wanted)
        self.assertEqual(
            sorted(changes),
            sorted(
                [
                    "AT+ETHERNET=0",
                    "AT+LOG_LEVEL=SILENT",
                    "AT+PROTOCOL_OUT=CONSOLE,BEAST",
                    "AT+WIFI_AP=0,ADSBee1090-9A3B7C,yummyflowers,1",
                    "AT+FEED=6,,0,0,NONE",
                    "AT+FEED=7,,0,0,NONE",
                    "AT+FEED=8,,0,0,NONE",
                    "AT+FEED=9,,0,0,NONE",
                ]
            ),
        )
        # Already-correct settings must not be rewritten: every rewrite is a
        # flash write on the RP2040.
        for unchanged in (
            "AT+WIFI_STA=0,,",
            "AT+RX_ENABLE=1",
            "AT+SUBG_ENABLE=1",
            "AT+ESP32_ENABLE=1",
            "AT+PROTOCOL_OUT=COMMS_UART,NONE",
            "AT+FEED=0,,0,0,NONE",
        ):
            self.assertNotIn(unchanged, changes)

    def test_locked_device_is_a_noop(self):
        current = _dump(LOCKED_DUMP)
        wanted = LOCKDOWN.desired_settings(current, disable_radio=True)
        self.assertEqual(LOCKDOWN.diff_settings(current, wanted), [])


class SatisfiedTest(unittest.TestCase):
    def test_feed_with_leftover_hostname_is_satisfied(self):
        # The firmware keeps the last hostname when a slot is cleared, so a
        # literal compare would rewrite the slot on every boot.
        self.assertTrue(
            LOCKDOWN.satisfied(
                "FEED:6",
                "AT+FEED=6,feed.whereplane.xyz,0,0,NONE",
                "AT+FEED=6,,0,0,NONE",
            )
        )

    def test_active_feed_is_not_satisfied(self):
        self.assertFalse(
            LOCKDOWN.satisfied(
                "FEED:6", "AT+FEED=6,feed.whereplane.xyz,0,1,RAW",
                "AT+FEED=6,,0,0,NONE",
            )
        )

    def test_missing_setting_is_not_satisfied(self):
        self.assertFalse(
            LOCKDOWN.satisfied("ETHERNET", None, "AT+ETHERNET=0")
        )


if __name__ == "__main__":
    unittest.main()
