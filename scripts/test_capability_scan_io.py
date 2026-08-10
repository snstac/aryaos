#!/usr/bin/env python3
"""Regression tests for bounded serial I/O during capability discovery."""

import importlib.machinery
import importlib.util
import os
import time
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-capability-scan")

spec = importlib.util.spec_from_loader(
    "capability_scan_io",
    importlib.machinery.SourceFileLoader("capability_scan_io", TOOL),
)
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class SerialIoTestCase(unittest.TestCase):
    def test_blocked_close_is_bounded(self):
        """An ESP32-S3 cdc_acm close must not freeze the root scanner."""
        original_close = scanner.os.close
        scanner.os.close = lambda _fd: time.sleep(5)
        started = time.monotonic()
        try:
            scanner._close_with_timeout(123, seconds=0.02)
        finally:
            scanner.os.close = original_close
        self.assertLess(time.monotonic() - started, 0.5)


class ProtocolDetectionTestCase(unittest.TestCase):
    class _ReadySelector:
        def register(self, *_args):
            pass

        def select(self, **_kwargs):
            return [(1, 1)]

        def close(self):
            pass

    def test_adsbee_requires_device_specific_at_reply(self):
        reply = b"\x1a\x33\x00\x01BIAS_TEE_ENABLE=0,0\r\n"
        with mock.patch.object(scanner.os.path, "exists", return_value=True), mock.patch.object(
            scanner, "_run", return_value=""
        ), mock.patch.object(scanner, "_open_nonblocking_with_timeout", return_value=42), mock.patch.object(
            scanner, "_set_raw_115200", return_value=[]
        ), mock.patch.object(scanner.termios, "tcflush"), mock.patch.object(
            scanner.os, "write"
        ) as write, mock.patch.object(
            scanner.selectors, "DefaultSelector", return_value=self._ReadySelector()
        ), mock.patch.object(scanner.os, "read", side_effect=[reply, b""]), mock.patch.object(
            scanner, "_restore_tty"
        ), mock.patch.object(scanner, "_close_with_timeout"):
            self.assertTrue(scanner.probe_adsbee("/dev/ttyACM0"))
        write.assert_called_once_with(42, b"AT+BIAS_TEE_ENABLE?\r\n")

    def test_generic_pico_ok_reply_is_not_adsbee(self):
        with mock.patch.object(scanner.os.path, "exists", return_value=True), mock.patch.object(
            scanner, "_run", return_value=""
        ), mock.patch.object(scanner, "_open_nonblocking_with_timeout", return_value=42), mock.patch.object(
            scanner, "_set_raw_115200", return_value=[]
        ), mock.patch.object(scanner.termios, "tcflush"), mock.patch.object(
            scanner.os, "write"
        ), mock.patch.object(
            scanner.selectors, "DefaultSelector", return_value=self._ReadySelector()
        ), mock.patch.object(scanner.os, "read", side_effect=[b"OK\r\n", b""]), mock.patch.object(
            scanner, "_restore_tty"
        ), mock.patch.object(scanner, "_close_with_timeout"):
            self.assertFalse(scanner.probe_adsbee("/dev/ttyACM0"))

    def test_busy_configured_adsbee_remains_detected(self):
        port = "/dev/serial/by-id/usb-Raspberry_Pi_Pico_ADSBee-if00"
        with mock.patch.object(scanner, "_serial_ports_by_id", return_value=[port]), mock.patch.object(
            scanner, "probe_adsbee", return_value=False
        ), mock.patch.object(scanner, "_config", return_value="adsbee"), mock.patch.object(
            scanner,
            "_read",
            return_value=f'RECEIVER_OPTIONS="--device-type modesbeast --beast-serial {port} --beast-baudrate 115200"',
        ):
            self.assertEqual(scanner.probe_adsbee_serial(), [port])

    def _scan(self, mavlink_result):
        patches = (
            mock.patch.object(scanner, "probe_sdrs", return_value=[]),
            mock.patch.object(scanner, "probe_wifi_monitor", return_value=[]),
            mock.patch.object(scanner, "probe_esp32_serial", return_value=[]),
            mock.patch.object(
                scanner,
                "probe_adsbee_serial",
                return_value=["/dev/serial/by-id/usb-Raspberry_Pi_Pico_ADSBee-if00"],
            ),
            mock.patch.object(
                scanner,
                "probe_ds110_uart_candidates",
                return_value=["/dev/serial/by-id/usb-Prolific_DS110-if00"],
            ),
            mock.patch.object(scanner, "probe_mavlink_stream", return_value=mavlink_result),
            mock.patch.object(scanner, "probe_antsdr", return_value=None),
            mock.patch.object(scanner, "probe_ais_serial", return_value=None),
            mock.patch.object(scanner, "probe_onboard_bt", return_value=[]),
            mock.patch.object(scanner, "unit_active", return_value=False),
        )
        with patches[0], patches[1], patches[2], patches[3], patches[4], patches[5], patches[6], patches[7], patches[8], patches[9]:
            return scanner.scan()

    def test_adsbee_is_a_usable_adsb_source_without_an_sdr(self):
        report = self._scan(
            {"status": "stuck-low", "bytes_read": 1024, "message_types": []}
        )
        self.assertTrue(report["capabilities"]["adsb"]["available"])
        self.assertTrue(report["capabilities"]["adsb"]["auto_apply"])
        self.assertIn("ADSBee", report["capabilities"]["adsb"]["evidence"])

    def test_stuck_low_pl2303_is_ambiguous_not_dronescout(self):
        report = self._scan(
            {"status": "stuck-low", "bytes_read": 1024, "message_types": []}
        )
        rid = report["capabilities"]["rid"]
        self.assertFalse(rid["available"])
        self.assertTrue(rid["ambiguous"])
        self.assertIn("stuck-low", rid["evidence"])

    def test_generic_pl2303_needs_remote_id_mavlink(self):
        report = self._scan(
            {"status": "mavlink", "bytes_read": 32, "message_types": ["HEARTBEAT"]}
        )
        self.assertFalse(report["capabilities"]["rid"]["available"])

    def test_esp32_heartbeat_could_be_sikw00f_not_dronescout(self):
        with mock.patch.object(scanner, "probe_sdrs", return_value=[]), mock.patch.object(
            scanner, "probe_wifi_monitor", return_value=[]
        ), mock.patch.object(
            scanner,
            "probe_esp32_serial",
            return_value=["/dev/serial/by-id/usb-Espressif_shared-if00"],
        ), mock.patch.object(scanner, "probe_adsbee_serial", return_value=[]), mock.patch.object(
            scanner, "probe_ds110_uart_candidates", return_value=[]
        ), mock.patch.object(
            scanner,
            "probe_mavlink_stream",
            return_value={"status": "mavlink", "bytes_read": 32, "message_types": ["HEARTBEAT"]},
        ), mock.patch.object(scanner, "probe_antsdr", return_value=None), mock.patch.object(
            scanner, "probe_ais_serial", return_value=None
        ), mock.patch.object(scanner, "probe_onboard_bt", return_value=[]), mock.patch.object(
            scanner, "unit_active", return_value=False
        ):
            report = scanner.scan()
        self.assertFalse(report["capabilities"]["rid"]["available"])
        self.assertTrue(report["capabilities"]["rid"]["ambiguous"])

    def test_remote_id_mavlink_verifies_ds110_path(self):
        report = self._scan(
            {
                "status": "mavlink",
                "bytes_read": 64,
                "message_types": ["ADSB_VEHICLE"],
            }
        )
        self.assertTrue(report["capabilities"]["rid"]["available"])
        self.assertEqual(
            report["hardware"]["rid_serial"],
            "/dev/serial/by-id/usb-Prolific_DS110-if00",
        )


class SdrProbeTestCase(unittest.TestCase):
    def test_probe_uses_bounded_local_enumeration(self):
        payload = '{"devices":[{"driver":"lime","serial":"0009072C00482223"}]}'
        with mock.patch.object(scanner, "_run", return_value=payload) as run:
            devices = scanner.probe_sdrs()

        run.assert_called_once_with(
            ["/usr/local/sbin/aryaos-sdr", "list-local"], timeout=20
        )
        self.assertEqual(devices[0]["driver"], "lime")

    def test_probe_ignores_invalid_enumerator_output(self):
        with mock.patch.object(scanner, "_run", return_value="not-json"):
            self.assertEqual(scanner.probe_sdrs(), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
