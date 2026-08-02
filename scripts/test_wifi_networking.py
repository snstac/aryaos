#!/usr/bin/env python3
"""Regression tests for Wi-Fi hotspot and Bluetooth PAN coexistence."""

from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class OnboardingNetworkTestCase(unittest.TestCase):
    def test_comitup_dnsmasq_uses_dynamic_interface_binding(self):
        runner = (ROOT / "shared_files/aryaos/run_comitup.sh").read_text()
        self.assertIn("dns-hotspot.conf", runner)
        self.assertIn("dns-connected.conf", runner)
        self.assertIn("bind-dynamic", runner)
        self.assertIn("/^bind-interfaces$/d", runner)

    def test_dispatcher_accepts_callback_reapply_event(self):
        dispatcher = (ROOT / "shared_files/aryaos/99-aryaos-dispatcher").read_text()
        self.assertIn("dhcp6-change|reapply)", dispatcher)

    def test_nodered_notification_is_bounded_and_best_effort(self):
        callback = (ROOT / "shared_files/aryaos/comitup-callback.sh").read_text()
        self.assertIn("--timeout=2", callback)
        self.assertIn("--tries=1", callback)
        self.assertIn('comitup_callback/${1:-}" || true', callback)


if __name__ == "__main__":
    unittest.main(verbosity=2)
