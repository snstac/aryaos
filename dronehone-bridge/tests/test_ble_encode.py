#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""Tests for BLE OpenDroneID encoder."""

import unittest

from dronehone_bridge.transport.ble_advertiser import (
    build_message_pack,
    encode_basic_id,
    encode_location_vector,
)


class TestBleEncode(unittest.TestCase):
    def test_basic_id_length(self) -> None:
        msg = encode_basic_id("1581F5YHX24BB002FUBN", ua_type=2, id_type=1)
        self.assertEqual(len(msg), 25)
        self.assertEqual(msg[0] >> 4, 0)  # BASIC_ID

    def test_location_vector(self) -> None:
        track = {
            "uasLat": 37.7599566,
            "uasLon": -122.4983164,
            "uasHae": 212.0,
            "uasHeading": 126.0,
            "uasHSpeed": 12.75,
            "opStatus": 2,
        }
        msg = encode_location_vector(track)
        assert msg is not None
        self.assertEqual(len(msg), 25)
        self.assertEqual(msg[0] >> 4, 1)  # LOCATION_VECTOR

    def test_message_pack(self) -> None:
        basic = encode_basic_id("UAS001")
        loc = encode_location_vector(
            {"uasLat": 37.0, "uasLon": -122.0, "uasHae": 100.0}
        )
        assert loc is not None
        pack = build_message_pack([basic, loc])
        self.assertEqual(pack[0] >> 4, 0xF)
        self.assertEqual(pack[2], 2)


if __name__ == "__main__":
    unittest.main()
