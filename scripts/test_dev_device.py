#!/usr/bin/env python3
"""Regression tests for dynamic AryaOS development-device discovery."""

import importlib.machinery
import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import socket
import subprocess
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


device = load_tool("aryaos_dev_device", "scripts/aryaos-dev-device")
inventory = load_tool("aryaos_dev_inventory", "scripts/aryaos-dev-inventory")


def beacon(uid="machine-1", hostname="aryaos-a001", fqdn="aryaos-a001.local"):
    return f"""<event uid="{uid}" stale="2099-01-01T00:00:00Z">
<point lat="0" lon="0"/><detail><__aryaos>
<host name="{hostname}" fqdn="{fqdn}"/>
<capabilities><capability name="gps"/><capability id="rid"/></capabilities>
</__aryaos></detail></event>""".encode()


class BeaconParsingTestCase(unittest.TestCase):
    def test_parses_only_aryaos_beacons_and_uses_packet_source(self):
        parsed = device.parse_beacon(beacon(), "192.0.2.10", now=100)
        self.assertEqual(parsed["hostname"], "aryaos-a001")
        self.assertEqual(parsed["fqdn"], "aryaos-a001.local")
        self.assertEqual(parsed["ip"], "192.0.2.10")
        self.assertEqual(parsed["capabilities"], ["gps", "rid"])
        self.assertIsNone(device.parse_beacon(b"<event/>", "192.0.2.10", now=100))

    def test_rejects_hostile_malformed_oversized_and_invalid_input(self):
        hostile = b"<!DOCTYPE x [<!ENTITY y 'boom'>]><event>&y;</event>"
        self.assertIsNone(device.parse_beacon(hostile, "192.0.2.10"))
        self.assertIsNone(device.parse_beacon(b"<event", "192.0.2.10"))
        self.assertIsNone(
            device.parse_beacon(b"x" * (device.MAX_DATAGRAM + 1), "192.0.2.10")
        )
        self.assertIsNone(device.parse_beacon(beacon(), "239.2.3.1"))

    def test_rejects_expired_cot_observation(self):
        expired = beacon().replace(
            b"2099-01-01T00:00:00Z", b"2020-01-01T00:00:00Z"
        )
        self.assertIsNone(device.parse_beacon(expired, "192.0.2.10", now=2_000_000_000))


class NeighborCacheTestCase(unittest.TestCase):
    def test_validates_ttl_schema_and_drops_expired_entries(self):
        payload = {
            "ok": True,
            "ttl_s": 240,
            "items": [
                {
                    "uid": "fresh",
                    "seen_at": 900,
                    "age_s": 100,
                    "source_ip": "192.0.2.20",
                    "host": {"name": "aryaos-fresh", "fqdn": "aryaos-fresh.local"},
                    "capabilities": [{"name": "adsb"}],
                },
                {
                    "uid": "old",
                    "seen_at": 700,
                    "age_s": 300,
                    "source_ip": "192.0.2.30",
                    "host": {"name": "aryaos-old"},
                },
            ],
        }
        nodes = device.parse_neighbors(payload, now=1000)
        self.assertEqual([item["uid"] for item in nodes], ["fresh"])
        self.assertEqual(nodes[0]["capabilities"], ["adsb"])
        self.assertEqual(device.parse_neighbors({"ok": True, "items": []}), [])

    def test_deduplicates_uid_and_prefers_direct_packet_source(self):
        cached = {
            "hostname": "aryaos-a001", "fqdn": "", "uid": "same",
            "ip": "192.0.2.99", "capabilities": [], "seen_at": 100,
            "source": "neighbor-cache",
        }
        direct = dict(cached, ip="192.0.2.10", source="multicast")
        merged = device.merge_nodes([cached, direct])
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["ip"], "192.0.2.10")


class SelectionTestCase(unittest.TestCase):
    def setUp(self):
        self.nodes = [
            {
                "hostname": "aryaos-a001", "fqdn": "aryaos-a001.local",
                "uid": "uid-a", "ip": "192.0.2.10",
            },
            {
                "hostname": "aryaos-b002", "fqdn": "aryaos-b002.local",
                "uid": "uid-b", "ip": "192.0.2.11",
            },
        ]

    def test_exact_hostname_fqdn_uid_and_ip_selection(self):
        for selector in ("aryaos-b002", "aryaos-b002.local", "uid-b", "192.0.2.11"):
            self.assertEqual(device.select_node(self.nodes, selector)["uid"], "uid-b")

    def test_zero_one_multiple_and_invalid_selection(self):
        self.assertEqual(device.select_node(self.nodes[:1], None)["uid"], "uid-a")
        with self.assertRaises(LookupError):
            device.select_node([], None)
        with self.assertRaises(RuntimeError):
            device.select_node(self.nodes, None)
        with self.assertRaises(device.InvalidInput):
            device.select_node(self.nodes, "pi@192.0.2.10")

    def test_machine_readable_list_and_resolve_output_are_clean(self):
        complete = dict(
            self.nodes[0], capabilities=["gps"], seen_at=100, age_s=0,
            source="multicast"
        )
        with mock.patch.object(device, "discover", return_value=[complete]):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(device.main(["list", "--json"]), 0)
            self.assertEqual(json.loads(output.getvalue())["devices"][0]["uid"], "uid-a")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(device.main(["resolve", "uid-a"]), 0)
            self.assertEqual(output.getvalue(), "192.0.2.10\n")


class InterfaceAndInventoryTestCase(unittest.TestCase):
    def test_interface_filtering(self):
        with mock.patch.object(
            device, "_interface_ipv4", return_value=[("eth0", "192.0.2.10"), ("wlan0", "10.0.0.2")]
        ):
            self.assertEqual(device.discovery_interfaces("eth0"), [("eth0", "192.0.2.10")])
            self.assertEqual(device.discovery_interfaces("10.0.0.2"), [("wlan0", "10.0.0.2")])
            with self.assertRaises(device.InvalidInput):
                device.discovery_interfaces("missing")

    def test_multicast_scan_joins_every_selected_interface(self):
        fake_socket = mock.MagicMock()
        with (
            mock.patch.object(
                device,
                "discovery_interfaces",
                return_value=[("eth0", "192.0.2.10"), ("wlan0", "10.0.0.2")],
            ),
            mock.patch.object(device.socket, "socket", return_value=fake_socket),
        ):
            self.assertEqual(
                device.multicast_scan(0.5, clock=mock.Mock(side_effect=[0.0, 1.0])),
                [],
            )
        memberships = [
            call
            for call in fake_socket.setsockopt.call_args_list
            if call.args[:2] == (socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP)
        ]
        self.assertEqual(len(memberships), 2)

    def test_dynamic_inventory_explicit_target_is_clean_json(self):
        with mock.patch.dict(
            os.environ,
            {"ARYAOS_SSH": "operator@192.0.2.50"},
            clear=True,
        ):
            data = inventory.inventory()
        hostvars = data["_meta"]["hostvars"]["aryaos-dev-device"]
        self.assertEqual(hostvars["ansible_host"], "192.0.2.50")
        self.assertEqual(hostvars["ansible_user"], "operator")

    def test_dynamic_inventory_uses_resolver_selector(self):
        result = subprocess.CompletedProcess([], 0, "192.0.2.60\n", "")
        with (
            mock.patch.dict(os.environ, {"ARYAOS_DEV_DEVICE": "aryaos-c003"}, clear=True),
            mock.patch.object(inventory.subprocess, "run", return_value=result) as run,
        ):
            data = inventory.inventory()
        self.assertEqual(
            data["_meta"]["hostvars"]["aryaos-dev-device"]["ansible_host"],
            "192.0.2.60",
        )
        self.assertEqual(run.call_args.args[0][-1], "aryaos-c003")

    def test_explicit_shell_target_precedes_discovery_selector(self):
        command = (
            ". scripts/lib/dev-device.sh; "
            "aryaos_dev_target \"$PWD\" operator@192.0.2.70"
        )
        result = subprocess.run(
            ["bash", "-c", command],
            cwd=ROOT,
            env={**os.environ, "ARYAOS_DEV_DEVICE": "would-not-match"},
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.stdout.strip(), "operator@192.0.2.70")

    def test_retired_static_address_has_no_tracked_matches(self):
        retired = "172.17.2." + "158"
        result = subprocess.run(
            ["git", "grep", "-n", retired],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
