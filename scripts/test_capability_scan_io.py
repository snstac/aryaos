#!/usr/bin/env python3
"""Regression tests for bounded serial I/O during capability discovery."""

import importlib.machinery
import importlib.util
import os
import time
import unittest

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
