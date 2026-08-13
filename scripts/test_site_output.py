#!/usr/bin/env python3
"""Regression checks for COTBridge site-output migration."""

import configparser
import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).parents[1]
SCRIPT = ROOT / "shared_files/aryaos/aryaos-site-output"


def load_helper():
    loader = importlib.machinery.SourceFileLoader("aryaos_site_output", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class SiteOutputMigrationTestCase(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.helper = load_helper()
        self.helper.BRIDGE = self.root / "cotbridge.ini"
        self.helper.CONFIG = self.root / "aryaos-config.txt"

    def tearDown(self):
        self.tempdir.cleanup()

    def test_migration_prefers_upstream_and_preserves_tls(self):
        self.helper.BRIDGE.write_text(
            """[cotbridge]
DEBUG = false

[lane:local-to-mesh]
enabled = true
ingress_cot_url = udp+ro://127.0.0.1:28087
egress_cot_url = udp+wo://239.2.3.1:6969

[lane:local-to-takserver]
enabled = true
ingress_cot_url = udp+ro://127.0.0.1:28087
egress_cot_url = tls://tak.example:8089
PYTAK_TLS_CLIENT_CERT = /etc/aryaos/tls/client.pem
"""
        )
        self.helper.CONFIG.write_text(
            'ARYAOS_COT_OUTPUT_URL="udp+wo://239.2.3.1:6969"\n'
        )
        parser = configparser.RawConfigParser()
        parser.optionxform = str
        parser.read(self.helper.BRIDGE)

        url, source = self.helper.selected_output(parser)
        with mock.patch.object(self.helper.os, "system", return_value=0):
            self.helper.update_output(parser, url, source=source)

        migrated = configparser.RawConfigParser()
        migrated.optionxform = str
        migrated.read(self.helper.BRIDGE)
        self.assertEqual(url, "tls://tak.example:8089")
        self.assertEqual(source, "lane:local-to-takserver")
        self.assertEqual(
            migrated.get("lane:site-output", "PYTAK_TLS_CLIENT_CERT"),
            "/etc/aryaos/tls/client.pem",
        )
        self.assertFalse(migrated.getboolean("lane:local-to-mesh", "enabled"))
        self.assertFalse(
            migrated.getboolean("lane:local-to-takserver", "enabled")
        )
        self.assertIn(
            'ARYAOS_COT_OUTPUT_URL="tls://tak.example:8089"',
            self.helper.CONFIG.read_text(),
        )

    def test_direct_update_disables_legacy_lane(self):
        parser = configparser.RawConfigParser()
        parser.add_section("lane:local-to-mesh")
        parser.set("lane:local-to-mesh", "enabled", "true")

        with mock.patch.object(self.helper.os, "system", return_value=0):
            self.helper.update_output(
                parser, "udp+wo://239.2.3.1:6969"
            )

        self.assertFalse(parser.getboolean("lane:local-to-mesh", "enabled"))
        self.assertEqual(
            parser.get("lane:site-output", "ingress_cot_url"),
            "udp+ro://127.0.0.1:28087",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
