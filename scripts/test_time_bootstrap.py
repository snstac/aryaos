#!/usr/bin/env python3
"""Regression tests for AryaOS resilient clock acquisition."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).parents[1]
HELPER = ROOT / "shared_files/aryaos/aryaos-time-bootstrap"
LOADER = importlib.machinery.SourceFileLoader("aryaos_time_bootstrap", str(HELPER))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
timeboot = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(timeboot)


def completed(argv, rc=0, stdout=""):
    return subprocess.CompletedProcess(argv, rc, stdout, "")


class TimeBootstrapTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.paths = {
            "NEIGHBORS": root / "run/gutcheck/neighbors.json",
            "RUNTIME_DIR": root / "run/aryaos",
            "CHRONY_SOURCE_DIR": root / "run/chrony-aryaos/sources",
            "CHRONY_SOURCE_FILE": root / "run/chrony-aryaos/sources/gutcheck.sources",
            "PEER_STATE": root / "run/aryaos/time-peers.json",
            "TIME_STATUS": root / "run/aryaos/time-status.json",
            "STEP_MARKER": root / "run/aryaos/time-step-attempted",
            "FLOOR_MARKER": root / "run/aryaos/time-floor-restored",
            "LOCK_FILE": root / "run/aryaos/time-bootstrap.lock",
            "LAST_GOOD": root / "var/lib/aryaos/time/last-good.json",
        }
        self.patchers = [mock.patch.object(timeboot, key, value) for key, value in self.paths.items()]
        for patcher in self.patchers:
            patcher.start()

    def tearDown(self):
        for patcher in reversed(self.patchers):
            patcher.stop()
        self.temp.cleanup()

    def _neighbor(self, **updates):
        item = {
            "uid": "peer-good",
            "age_s": 3,
            "host": {"name": "aryaos-good", "ip": "10.20.30.40"},
            "time": {"synced": "yes", "leap": "normal", "stratum": "1"},
            "system": {"timestamp": 1_787_600_000},
        }
        item.update(updates)
        return item

    def test_candidates_require_fresh_same_link_synchronized_peers(self):
        good = self._neighbor()
        # GutCheck 0.4.2 carries freshness and clock-quality metadata but does
        # not retain the peer's <system timestamp> in its cache.
        good["system"] = {}
        items = [
            good,
            self._neighbor(uid="stale", age_s=31, host={"ip": "10.20.30.41"}),
            self._neighbor(uid="local", host={"ip": "10.20.30.42"}),
            self._neighbor(
                uid="unsynced",
                host={"ip": "10.20.30.43"},
                time={"synced": "no", "leap": "normal", "stratum": "1"},
            ),
            self._neighbor(
                uid="local-clock",
                host={"ip": "10.20.30.44"},
                time={"synced": "yes", "leap": "normal", "stratum": "10"},
            ),
            self._neighbor(uid="routed", host={"ip": "10.20.30.45"}),
            self._neighbor(
                uid="loop",
                host={"ip": "10.20.30.46"},
                time={
                    "synced": "yes",
                    "leap": "normal",
                    "stratum": "2",
                    "source": "peer_ntp",
                },
            ),
        ]
        self.paths["NEIGHBORS"].parent.mkdir(parents=True)
        self.paths["NEIGHBORS"].write_text(json.dumps({"items": items}))

        with mock.patch.object(timeboot, "_local_addresses", return_value={"10.20.30.42"}), mock.patch.object(
            timeboot, "_direct_route", side_effect=lambda address: address != "10.20.30.45"
        ), mock.patch.dict(timeboot.os.environ, {}, clear=True):
            candidates = timeboot._candidate_items()

        self.assertEqual([item["uid"] for item in candidates], ["peer-good"])

    def test_peer_mode_can_disable_fallback(self):
        with mock.patch.dict(timeboot.os.environ, {"ARYAOS_TIME_PEER_MODE": "off"}, clear=True):
            self.assertEqual(timeboot._candidate_items(), [])

    def test_ntp_response_must_correspond_to_advertised_peer_time(self):
        nonce = b"12345678"
        candidate = self._neighbor()
        candidate = {
            "uid": candidate["uid"],
            "host": "aryaos-good",
            "ip": candidate["host"]["ip"],
            "age_s": candidate["age_s"],
            "stratum": 1,
            "peer_epoch": candidate["system"]["timestamp"],
        }
        response = bytearray(48)
        response[0] = (4 << 3) | 4
        response[1] = 1
        response[24:32] = nonce
        seconds = int(candidate["peer_epoch"] + timeboot.NTP_EPOCH)
        response[40:48] = struct.pack("!II", seconds, 0)

        accepted = timeboot._parse_ntp_response(
            bytes(response), candidate["ip"], nonce, candidate, 0.02, 2.5
        )
        self.assertEqual(accepted["ntp_stratum"], 1)

        without_cached_epoch = {key: value for key, value in candidate.items() if key != "peer_epoch"}
        self.assertIsNotNone(
            timeboot._parse_ntp_response(
                bytes(response),
                candidate["ip"],
                nonce,
                without_cached_epoch,
                0.02,
                2.5,
            )
        )

        response[24:32] = b"badnonce"
        self.assertIsNone(
            timeboot._parse_ntp_response(
                bytes(response), candidate["ip"], nonce, candidate, 0.02, 2.5
            )
        )

        response[24:32] = nonce
        response[40:48] = struct.pack("!II", seconds + 121, 0)
        self.assertIsNone(
            timeboot._parse_ntp_response(
                bytes(response), candidate["ip"], nonce, candidate, 0.02, 2.5
            )
        )

    def test_dynamic_sources_are_ephemeral_and_reload_only_on_change(self):
        peers = [{"ip": "10.20.30.40", "uid": "p1", "host": "peer"}]
        with mock.patch.object(timeboot, "_run", return_value=completed([])) as run:
            self.assertTrue(timeboot._write_peer_sources(peers))
            self.assertFalse(timeboot._write_peer_sources(peers))

        self.assertEqual(
            self.paths["CHRONY_SOURCE_FILE"].read_text(),
            "server 10.20.30.40 iburst minpoll 4 maxpoll 6\n",
        )
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands.count([timeboot.CHRONYC, "reload", "sources"]), 1)

    def test_restore_floor_only_moves_clock_forward(self):
        self.paths["LAST_GOOD"].parent.mkdir(parents=True)
        self.paths["LAST_GOOD"].write_text(json.dumps({"epoch": 1_787_600_000}))
        with mock.patch.object(timeboot.time, "time", return_value=1_700_000_000), mock.patch.object(
            timeboot, "_run", return_value=completed([])
        ) as run:
            self.assertEqual(timeboot.restore_floor(), 0)
        run.assert_called_once_with(
            [timeboot.DATE, "-u", "--set", "@1787600000.000000"], timeout=10.0
        )

        with mock.patch.object(timeboot.time, "time", return_value=1_800_000_000), mock.patch.object(
            timeboot, "_run", return_value=completed([])
        ) as run:
            self.assertEqual(timeboot.restore_floor(), 0)
        run.assert_not_called()

    def test_last_good_is_saved_only_from_a_trustworthy_clock(self):
        trusted = {
            "synchronized": True,
            "source_kind": "gnss_pps",
            "source": "PPS",
            "stratum": 1,
        }
        with mock.patch.object(timeboot.time, "time", return_value=1_787_600_000):
            self.assertTrue(timeboot.save_last_good(trusted))
            self.assertFalse(timeboot.save_last_good(trusted))
            self.assertFalse(timeboot.save_last_good({**trusted, "synchronized": False}))

        saved = json.loads(self.paths["LAST_GOOD"].read_text())
        self.assertEqual(saved["source"], "gnss_pps")


if __name__ == "__main__":
    unittest.main()
