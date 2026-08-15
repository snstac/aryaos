#!/usr/bin/env python3
"""Unit tests for the landing portal status CGI."""

import importlib.machinery
import importlib.util
import socket
import tempfile
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

    def test_returns_as_soon_as_complete_snapshot_arrives(self):
        fake = FakeSocket(
            [
                b'{"class":"VERSION"}\n'
                b'{"class":"TPV","mode":3,"lat":1,"lon":2}\n'
                b'{"class":"SKY","uSat":8}\n'
            ]
        )
        with mock.patch.object(PORTAL.socket, "create_connection", return_value=fake):
            stdout, code, error = PORTAL.read_gpsd(
                max_lines=40,
                timeout=3,
                stop_when=PORTAL._gps_snapshot_ready,
            )

        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertIn('"class":"TPV"', stdout)
        self.assertIn('"class":"SKY"', stdout)

    def test_valid_fix_waits_past_initial_empty_sky(self):
        fake = FakeSocket(
            [
                b'{"class":"TPV","mode":3,"lat":1,"lon":2}\n'
                b'{"class":"SKY","uSat":0}\n',
                b'{"class":"SKY","uSat":8}\n',
            ]
        )
        with mock.patch.object(PORTAL.socket, "create_connection", return_value=fake):
            stdout, code, error = PORTAL.read_gpsd(
                max_lines=40,
                timeout=3,
                stop_when=PORTAL._gps_snapshot_ready,
            )

        self.assertEqual(code, 0)
        self.assertEqual(error, "")
        self.assertIn('"uSat":8', stdout)

    def test_gather_gps_uses_compact_sky_counters(self):
        snapshot = (
            '{"class":"TPV","mode":3,"lat":1,"lon":2}\n'
            '{"class":"SKY","nSat":12,"uSat":8}\n'
        )
        with mock.patch.object(PORTAL, "read_gpsd", return_value=(snapshot, 0, "")):
            gps = PORTAL.gather_gps()

        self.assertEqual(gps["satellites_visible"], 12)
        self.assertEqual(gps["satellites_used"], 8)


class RadioInventoryTestCase(unittest.TestCase):
    def test_limesdr_mini_has_model_and_frequency_range(self):
        with tempfile.TemporaryDirectory() as root:
            device = Path(root) / "2-1"
            device.mkdir()
            values = {
                "idVendor": "0403\n",
                "idProduct": "601f\n",
                "manufacturer": "Lime Micro\n",
                "product": "LimeSDR Mini\n",
                "serial": "1DBB4189078E3F\n",
            }
            for name, value in values.items():
                (device / name).write_text(value, encoding="utf-8")

            radios = []
            with mock.patch.object(PORTAL, "SYS_USB", root):
                PORTAL._gather_usb_sdr(radios)

        self.assertEqual(len(radios), 1)
        self.assertEqual(radios[0]["kind"], "usb_sdr")
        self.assertEqual(radios[0]["label"], "LimeSDR Mini")
        self.assertEqual(
            radios[0]["frequency_range_mhz"], {"min": 10, "max": 3500}
        )

    def test_generic_ft601_is_not_misidentified_as_limesdr(self):
        with tempfile.TemporaryDirectory() as root:
            device = Path(root) / "2-1"
            device.mkdir()
            values = {
                "idVendor": "0403\n",
                "idProduct": "601f\n",
                "manufacturer": "FTDI\n",
                "product": "FT601 USB bridge\n",
            }
            for name, value in values.items():
                (device / name).write_text(value, encoding="utf-8")

            radios = []
            with mock.patch.object(PORTAL, "SYS_USB", root):
                PORTAL._gather_usb_sdr(radios)

        self.assertEqual(radios, [])


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

    def test_gateway_inventory_includes_acarscot(self):
        with mock.patch.object(
            PORTAL, "_gateway_item", side_effect=lambda unit_id, *_args: {"id": unit_id}
        ):
            result = PORTAL.gather_tac_gateways()

        self.assertIn("acarscot", {item["id"] for item in result["items"]})


class PortalMarkupTestCase(unittest.TestCase):
    def test_sensor_strip_has_acars_and_sdr_chips(self):
        root = Path(__file__).parents[1] / "shared_files/aryaos/html"
        html = (root / "index.html").read_text(encoding="utf-8")
        javascript = (root / "js/portal-landing.js").read_text(encoding="utf-8")

        self.assertIn('id="aos-tak-chip-acarscot"', html)
        self.assertIn('id="aos-tak-chip-sdr"', html)
        self.assertIn("function fillSdrChip(radios)", javascript)
        self.assertIn('"acarscot"', javascript)


if __name__ == "__main__":
    unittest.main(verbosity=2)
