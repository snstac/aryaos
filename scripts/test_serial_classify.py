#!/usr/bin/env python3
"""Regression tests for binary-safe GPS/AIS serial classification."""

import importlib.machinery
import importlib.util
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-serial-classify")
spec = importlib.util.spec_from_loader(
    "serial_classify", importlib.machinery.SourceFileLoader("serial_classify", TOOL)
)
classifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(classifier)


def sirf_frame(payload: bytes, checksum_delta: int = 0) -> bytes:
    checksum = ((sum(payload) & 0x7FFF) + checksum_delta) & 0x7FFF
    return (
        b"\xa0\xa2"
        + len(payload).to_bytes(2, "big")
        + payload
        + checksum.to_bytes(2, "big")
        + b"\xb0\xb3"
    )


def nmea(body: bytes) -> bytes:
    checksum = 0
    for byte in body:
        checksum ^= byte
    return b"$" + body + b"*" + f"{checksum:02X}".encode() + b"\r\n"


class SerialClassifierTestCase(unittest.TestCase):
    def test_valid_sirf_binary_is_gps(self):
        payload = bytes.fromhex("38 29 00 00 ff ff ff ff 05 7a 4f ad")
        sample = b"\x00\x01noise" + sirf_frame(payload) + b"\x00"
        self.assertEqual(classifier.classify_sample(sample), "gps:sirf")

    def test_bad_sirf_checksum_is_rejected(self):
        self.assertEqual(classifier.classify_sample(sirf_frame(b"\x38\x29", 1)), "")

    def test_checksum_valid_nmea_gps_is_detected(self):
        sample = nmea(b"GPGGA,123519,4807.038,N,01131.000,E,1,08")
        self.assertEqual(classifier.classify_sample(sample), "gps:nmea")

    def test_checksum_valid_nmea_ais_is_detected(self):
        body = b"AIVDM,1,1,,A,15Muq?P0000G?tN>E`K6?wvl0<0u,0"
        checksum = 0
        for byte in body:
            checksum ^= byte
        sample = b"!" + body + b"*" + f"{checksum:02X}".encode() + b"\r\n"
        self.assertEqual(classifier.classify_sample(sample), "ais:nmea")

    def test_bad_nmea_checksum_is_rejected(self):
        self.assertEqual(classifier.classify_sample(b"$GPGGA,broken*00\r\n"), "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
