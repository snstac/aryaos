#!/usr/bin/env python3
"""Tests for burn-in summary evidence and service-drop detection."""

import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest


TOOL = Path(__file__).with_name("aryaos-burnin.py")
spec = importlib.util.spec_from_loader(
    "aryaos_burnin",
    importlib.machinery.SourceFileLoader("aryaos_burnin", str(TOOL)),
)
burnin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(burnin)


def sample(cycle, memory, state, filesystem=None):
    return {
        "host": "192.0.2.1",
        "cycle": cycle,
        "ok": True,
        "temperature_c": 40,
        "load": [0.5, 0.4, 0.3],
        "memory": {"used_pct": memory},
        "disk": {"used_pct": 25},
        "throttled": "throttled=0x0",
        "failed_units": [],
        "services": {
            "role-service": {"ActiveState": state, "NRestarts": 0},
            "optional-service": {"ActiveState": "inactive", "NRestarts": 0},
        },
        "filesystem": filesystem or {
            "root_state": "clean",
            "boot_cmdline_lines": 1,
            "boot_root_matches": True,
        },
    }


class BurninSummaryTestCase(unittest.TestCase):
    def test_records_memory_drift_and_service_states(self):
        host = burnin.summarize(
            [sample(1, 10.25, "active"), sample(2, 11.75, "inactive")]
        )["hosts"]["192.0.2.1"]

        self.assertEqual(host["first_mem_pct"], 10.25)
        self.assertEqual(host["last_mem_pct"], 11.75)
        self.assertEqual(host["mem_delta_pct"], 1.5)
        self.assertEqual(
            host["service_state_counts"]["role-service"],
            {"active": 1, "inactive": 1},
        )
        self.assertEqual(host["service_nonactive"]["role-service"], 1)

    def test_always_inactive_optional_service_is_not_an_alarm(self):
        host = burnin.summarize(
            [sample(1, 10, "active"), sample(2, 10, "active")]
        )["hosts"]["192.0.2.1"]

        self.assertNotIn("optional-service", host["service_nonactive"])

    def test_reads_existing_jsonl_and_skips_blank_lines(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "samples.jsonl"
            path.write_text('{"host":"one","ok":false}\n\n')

            self.assertEqual(
                burnin.read_samples(path), [{"host": "one", "ok": False}]
            )

    def test_existing_jsonl_error_names_line(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "samples.jsonl"
            path.write_text('{"host":"one"}\nnot-json\n')

            with self.assertRaisesRegex(ValueError, r"samples\.jsonl:2"):
                burnin.read_samples(path)

    def test_filesystem_damage_and_bad_boot_root_are_counted(self):
        host = burnin.summarize(
            [
                sample(1, 10, "active"),
                sample(
                    2,
                    10,
                    "active",
                    {
                        "root_state": "clean with errors",
                        "boot_cmdline_lines": 2,
                        "boot_root_matches": False,
                    },
                ),
            ]
        )["hosts"]["192.0.2.1"]

        self.assertEqual(host["filesystem_alerts"], 1)
        self.assertEqual(host["filesystem_states"], ["clean", "clean with errors"])

    def test_invalid_media_identity_and_boot_artifacts_are_counted(self):
        damaged = sample(2, 10, "active")
        damaged["filesystem"].update(
            media_manfid="0x000000",
            media_manfid_valid=False,
            boot_cmdline_printable=False,
            boot_artifacts_ok=False,
        )

        host = burnin.summarize(
            [sample(1, 10, "active"), damaged]
        )["hosts"]["192.0.2.1"]

        self.assertEqual(host["filesystem_alerts"], 1)

    def test_overlapping_journal_windows_count_unique_events_once(self):
        first = sample(1, 10, "active")
        second = sample(2, 10, "active")
        first.update(
            journal_warning_count_2m=2,
            journal_warning_events_2m=[
                {"cursor": "one", "message": "first warning"},
                {"cursor": "two", "message": "second warning"},
            ],
        )
        second.update(
            journal_warning_count_2m=2,
            journal_warning_events_2m=[
                {"cursor": "two", "message": "second warning"},
                {"cursor": "three", "message": "second warning"},
            ],
        )

        host = burnin.summarize([first, second])["hosts"]["192.0.2.1"]

        self.assertEqual(host["journal_warning_observations"], 4)
        self.assertEqual(host["journal_warning_unique_events"], 3)
        self.assertEqual(
            host["journal_warning_unique_messages"],
            ["first warning", "second warning"],
        )

    def test_failed_units_preserve_history_and_current_state(self):
        first = sample(1, 10, "active")
        second = sample(2, 10, "active")
        first["failed_units"] = ["transient.service failed"]

        host = burnin.summarize([first, second])["hosts"]["192.0.2.1"]

        self.assertEqual(host["failed_units"], ["transient.service failed"])
        self.assertEqual(host["failed_unit_samples"], 1)
        self.assertEqual(host["last_failed_units"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
