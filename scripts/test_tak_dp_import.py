#!/usr/bin/env python3
"""Regression checks for the TAK connection-package importer."""

import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock
import zipfile


ROOT = Path(__file__).parents[1]
IMPORTER_PATH = ROOT / "shared_files/aryaos/aryaos-import-tak-dp"
FRONTEND_PATH = ROOT / "shared_files/aryaos/aryaos-tak-dp-import"


def load_importer():
    loader = importlib.machinery.SourceFileLoader("aryaos_import_tak_dp", str(IMPORTER_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def load_frontend():
    loader = importlib.machinery.SourceFileLoader("aryaos_tak_dp_import", str(FRONTEND_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class TakDataPackageImportTestCase(unittest.TestCase):
    def test_tls_import_updates_shared_config_before_restart(self):
        importer = load_importer()
        preferences = b"""<?xml version="1.0" encoding="UTF-8"?>
<preferences>
  <preference name="cot_streams">
    <entry key="certificateLocation0">client.p12</entry>
    <entry key="caLocation0">ca.p12</entry>
    <entry key="connectString0">tak.example.test:8089:ssl</entry>
    <entry key="description0">Test TAK Server</entry>
  </preference>
</preferences>
"""
        with tempfile.TemporaryDirectory() as tmpdir:
            package = Path(tmpdir) / "connection.zip"
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("config.pref", preferences)
                archive.writestr("client.p12", b"client bundle")
                archive.writestr("ca.p12", b"CA bundle")

            with (
                mock.patch.object(importer, "install_tls_files") as install_tls,
                mock.patch.object(importer, "update_cotbridge") as update_cotbridge,
                mock.patch.object(importer, "update_kv_file") as update_kv_file,
                mock.patch.object(
                    importer,
                    "resolve_server_expected_hostname",
                    return_value="tak",
                ),
                mock.patch.object(importer.subprocess, "run") as run,
            ):
                result = importer.import_package(str(package))

        install_tls.assert_called_once_with(b"client bundle", "", b"CA bundle", "")
        update_cotbridge.assert_called_once_with("tak.example.test", 8089, "ssl", "tak")
        update_kv_file.assert_called_once_with(
            importer.ARYAOS_CONFIG,
            {
                "ARYAOS_COT_OUTPUT_URL": "tls://tak.example.test:8089",
                "PYTAK_TLS_CLIENT_CERT": str(importer.TLS_DIR / "client.pem"),
                "PYTAK_TLS_CLIENT_KEY": str(importer.TLS_DIR / "client.key"),
                "PYTAK_TLS_CLIENT_CAFILE": str(importer.TLS_DIR / "ca.pem"),
                "PYTAK_TLS_SERVER_EXPECTED_HOSTNAME": "tak",
            },
        )
        run.assert_called_once_with(
            ["/usr/bin/systemctl", "try-restart", "cotbridge.service"], check=False
        )
        self.assertEqual(result["cot_url"], "tls://tak.example.test:8089")

    def test_server_expected_hostname_accepts_exact_or_short_dns_name(self):
        importer = load_importer()

        exact = {"subjectAltName": (("DNS", "tak.example.test"),)}
        short = {"subjectAltName": (("DNS", "tak"),)}

        self.assertEqual(
            importer.select_expected_hostname("tak.example.test", exact),
            "tak.example.test",
        )
        self.assertEqual(
            importer.select_expected_hostname("tak.example.test", short),
            "tak",
        )

    def test_server_expected_hostname_rejects_unrelated_ca_certificate(self):
        importer = load_importer()
        unrelated = {"subjectAltName": (("DNS", "other"),)}

        with self.assertRaises(SystemExit):
            importer.select_expected_hostname("tak.example.test", unrelated)

    def test_enrollment_url_can_be_supplied_without_argv_secret(self):
        frontend = load_frontend()
        enrollment_url = "tak://com.atakmap.app/enroll?host=tak.example.test&token=secret"
        sent = []
        fake_stdin = types.SimpleNamespace(buffer=io.BytesIO(enrollment_url.encode()))

        with (
            mock.patch.object(sys, "argv", [str(FRONTEND_PATH), "--enroll-stdin"]),
            mock.patch.object(sys, "stdin", fake_stdin),
            mock.patch.object(frontend, "send_to_daemon", side_effect=sent.append),
        ):
            frontend.main()

        self.assertEqual(len(sent), 1)
        request = json.loads(sent[0])
        self.assertEqual(request["type"], "enrollment_url")
        self.assertEqual(request["enrollment_url"], enrollment_url)


if __name__ == "__main__":
    unittest.main()
