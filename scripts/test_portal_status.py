#!/usr/bin/env python3
"""Unit tests for the landing portal status CGI."""

import importlib.machinery
import importlib.util
import socket
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "shared_files/aryaos/cgi-bin/aryaos-portal-status"
LOADER = importlib.machinery.SourceFileLoader("aryaos_portal_status", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
PORTAL = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(PORTAL)


class FakeSocket:
    def __init__(self, chunks):
        self.chunks = iter(chunks)
        self.sent = b""
        self.timeouts = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def sendall(self, payload):
        self.sent += payload

    def settimeout(self, timeout):
        self.timeouts.append(timeout)

    def recv(self, _size):
        result = next(self.chunks)
        if isinstance(result, Exception):
            raise result
        return result


class GpsdReadTestCase(unittest.TestCase):
    def test_stops_at_requested_report_count(self):
        fake = FakeSocket([b'{"class":"VERSION"}\n{"class":"TPV","mode":1}\n'])
        with mock.patch.object(PORTAL.socket, "create_connection", return_value=fake):
            stdout, code, error = PORTAL.read_gpsd(max_lines=2, timeout=1)

        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertEqual(
            stdout.splitlines(),
            ['{"class":"VERSION"}', '{"class":"TPV","mode":1}'],
        )
        self.assertEqual(fake.sent, b'?WATCH={"enable":true,"json":true};\n')
        self.assertTrue(fake.timeouts)

    def test_returns_partial_reports_on_timeout(self):
        fake = FakeSocket([b'{"class":"VERSION"}\n', socket.timeout()])
        with mock.patch.object(PORTAL.socket, "create_connection", return_value=fake):
            stdout, code, error = PORTAL.read_gpsd(max_lines=40, timeout=1)

        self.assertEqual(stdout, '{"class":"VERSION"}')
        self.assertEqual(code, -1)
        self.assertEqual(error, "gpsd timed out (using partial capture)")

    def test_reports_connection_failure(self):
        with mock.patch.object(
            PORTAL.socket,
            "create_connection",
            side_effect=ConnectionRefusedError("gpsd unavailable"),
        ):
            stdout, code, error = PORTAL.read_gpsd(timeout=1)

        self.assertEqual(stdout, "")
        self.assertEqual(code, -1)
        self.assertEqual(error, "gpsd unavailable")


class TakGatewayTestCase(unittest.TestCase):
    @staticmethod
    def systemctl_run(states):
        def fake_run(argv, timeout=8):
            del timeout
            unit = Path(argv[2]).stem
            load, active, enabled = states.get(unit, ("not-found", "inactive", "disabled"))
            return (
                f"LoadState={load}\nActiveState={active}\nUnitFileState={enabled}",
                0,
                "",
            )

        return fake_run

    def test_uas_is_up_when_dronescout_instance_is_active(self):
        states = {
            "dronecot": ("loaded", "inactive", "disabled"),
            "dronecot-dronescout": ("loaded", "active", "enabled"),
        }
        with mock.patch.object(PORTAL, "run", side_effect=self.systemctl_run(states)):
            item = PORTAL._gateway_item(
                "dronecot",
                "UAS / Remote ID→TAK",
                "UAS",
                ("dronecot", "dronecot-wifi", "dronecot-ble", "dronecot-dronescout"),
            )

        self.assertEqual(item["state"], "up")
        self.assertEqual(item["active_state"], "active")
        self.assertEqual(item["unit_file_state"], "enabled")
        self.assertIn("dronecot-dronescout active=active", item["title"])

    def test_uas_is_degraded_when_one_enabled_instance_failed(self):
        states = {
            "dronecot-wifi": ("loaded", "failed", "enabled"),
            "dronecot-dronescout": ("loaded", "active", "enabled"),
        }
        with mock.patch.object(PORTAL, "run", side_effect=self.systemctl_run(states)):
            item = PORTAL._gateway_item(
                "dronecot",
                "UAS / Remote ID→TAK",
                "UAS",
                ("dronecot-wifi", "dronecot-dronescout"),
            )

        self.assertEqual(item["state"], "degraded")
        self.assertEqual(item["active_state"], "degraded")


if __name__ == "__main__":
    unittest.main(verbosity=2)
