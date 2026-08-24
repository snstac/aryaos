#!/usr/bin/env python3
"""Regression tests for DHCP-less Ethernet and multicast link selection."""

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).parents[1]


def load_tool(name: str, relative: str):
    path = ROOT / relative
    spec = importlib.util.spec_from_loader(
        name, importlib.machinery.SourceFileLoader(name, str(path))
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ipv4ll = load_tool("aryaos_ipv4ll", "shared_files/aryaos/aryaos-ipv4ll")
links = load_tool(
    "aryaos_multicast_links", "shared_files/aryaos/aryaos-multicast-links"
)


class IPv4LLTestCase(unittest.TestCase):
    def test_default_is_enabled_and_disabled_is_explicit(self):
        self.assertIn("ipv4.link-local=3", ipv4ll._nm_default(True))
        self.assertIn("ipv4.link-local=2", ipv4ll._nm_default(False))
        self.assertIn("ipv4.required-timeout=0", ipv4ll._nm_default(True))
        self.assertNotIn("ipv6.method", ipv4ll._nm_default(True))
        self.assertIn("match-device=type:ethernet", ipv4ll._nm_default(True))

    def test_setting_preserves_unknown_site_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "aryaos-config.txt"
            config.write_text("COT_HOST_ID=test\nUNKNOWN=keep\n", encoding="utf-8")
            with mock.patch.object(ipv4ll, "CONFIG_PATH", config):
                ipv4ll._set_config(False)
                self.assertFalse(ipv4ll._configured_enabled())
                ipv4ll._set_config(True)
                self.assertTrue(ipv4ll._configured_enabled())
            text = config.read_text(encoding="utf-8")
            self.assertIn("UNKNOWN=keep", text)
            self.assertEqual(text.count("ARYAOS_IPV4LL_FALLBACK="), 1)

    def test_status_checks_exact_networkmanager_default(self):
        with tempfile.TemporaryDirectory() as directory:
            nm_config = Path(directory) / "ipv4ll.conf"
            nm_config.write_text(
                "# 3=enabled, 2=disabled\nipv4.link-local=2\n",
                encoding="utf-8",
            )
            with mock.patch.object(ipv4ll, "NM_CONF_PATH", nm_config):
                self.assertEqual(ipv4ll._networkmanager_default(), "2")

    def test_only_auto_non_sensor_ethernet_profiles_are_migrated(self):
        listing = subprocess.CompletedProcess(
            [], 0, "u1:802-3-ethernet\nu2:802-3-ethernet\nu3:wifi\n", ""
        )
        details = {
            "u1": "Wired connection 1\nend0\npublic\nauto\nauto\n-1\nauto\n",
            "u2": "AryaOS ANTSDR\neth1\ntrusted\nmanual\ndisabled\n-1\ndisabled\n",
        }

        def run(args, **_kwargs):
            if args[-2:] == ["connection", "show"]:
                return listing
            uuid = args[-1]
            return subprocess.CompletedProcess([], 0, details[uuid], "")

        with mock.patch.object(ipv4ll, "_run", side_effect=run):
            profiles = ipv4ll._connection_profiles()
        self.assertEqual([item["uuid"] for item in profiles], ["u1"])

    def test_apply_uses_numeric_enum_and_materializes_public_zone(self):
        profiles = [
            {
                "uuid": "u1",
                "name": "Wired connection 1",
                "interface": "end0",
                "zone": "",
                "method": "auto",
                "link_local": "0",
                "required_timeout": "-1",
                "ipv6_method": "auto",
            },
            {
                "uuid": "u2",
                "name": "Site Ethernet",
                "interface": "end1",
                "zone": "site-zone",
                "method": "auto",
                "link_local": "3",
                "required_timeout": "0",
                "ipv6_method": "link-local",
            },
        ]
        result = subprocess.CompletedProcess([], 0, "", "")
        with (
            mock.patch.object(ipv4ll, "_connection_profiles", return_value=profiles),
            mock.patch.object(ipv4ll, "_run", return_value=result) as run,
        ):
            ipv4ll._apply_profiles(True)

        modify_calls = [
            call.args[0]
            for call in run.call_args_list
            if call.args[0][:3] == ["nmcli", "connection", "modify"]
        ]
        self.assertEqual(len(modify_calls), 1)
        modify = modify_calls[0]
        self.assertEqual(
            modify,
            [
                "nmcli",
                "connection",
                "modify",
                "uuid",
                "u1",
                "ipv4.link-local",
                "3",
                "ipv4.required-timeout",
                "0",
                "ipv6.method",
                "link-local",
                "connection.zone",
                "public",
            ],
        )
        self.assertNotIn("u2", modify)


class MulticastLinksTestCase(unittest.TestCase):
    def test_auto_selects_one_address_per_physical_link(self):
        payload = [
            {
                "ifname": "end0",
                "flags": ["UP", "MULTICAST"],
                "addr_info": [
                    {"family": "inet", "local": "169.254.8.9"},
                    {"family": "inet", "local": "192.0.2.10"},
                ],
            },
            {
                "ifname": "wlan0",
                "flags": ["UP", "MULTICAST"],
                "addr_info": [{"family": "inet", "local": "10.41.0.1"}],
            },
            {
                "ifname": "docker0",
                "flags": ["UP", "MULTICAST"],
                "addr_info": [{"family": "inet", "local": "172.18.0.1"}],
            },
        ]
        result = subprocess.CompletedProcess([], 0, json.dumps(payload), "")
        with (
            mock.patch.object(links, "_run", return_value=result),
            mock.patch.object(links, "_connection_is_sensor", return_value=False),
        ):
            self.assertEqual(links._auto_addresses(), ["192.0.2.10", "10.41.0.1"])

    def test_auto_falls_back_to_ipv4ll_and_then_unspecified(self):
        payload = [
            {
                "ifname": "end0",
                "flags": ["UP", "MULTICAST"],
                "addr_info": [{"family": "inet", "local": "169.254.8.9"}],
            }
        ]
        result = subprocess.CompletedProcess([], 0, json.dumps(payload), "")
        with (
            mock.patch.object(links, "_run", return_value=result),
            mock.patch.object(links, "_connection_is_sensor", return_value=False),
            mock.patch.object(links, "_requested", return_value="auto"),
        ):
            self.assertEqual(links.resolve(), ["169.254.8.9"])
        with (
            mock.patch.object(
                links,
                "_run",
                return_value=subprocess.CompletedProcess([], 0, "[]", ""),
            ),
            mock.patch.object(links, "_requested", return_value="auto"),
        ):
            self.assertEqual(links.resolve(), ["0.0.0.0"])

    def test_explicit_list_is_normalized_and_deduplicated(self):
        with mock.patch.object(
            links, "_requested", return_value="192.0.2.010, 169.254.2.3 169.254.2.3"
        ):
            with self.assertRaises(ValueError):
                links.resolve()
        with mock.patch.object(
            links, "_requested", return_value="192.0.2.10, 169.254.2.3 192.0.2.10"
        ):
            self.assertEqual(links.resolve(), ["192.0.2.10", "169.254.2.3"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
