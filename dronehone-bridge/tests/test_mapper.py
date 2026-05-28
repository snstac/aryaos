#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""Tests for DroneHone JSON mapper."""

import unittest

from dronehone_bridge import constants
from dronehone_bridge.map.dronehone_json import (
    odid_to_dronehone_json,
    recv_method_from_sensor_type,
)


class TestRecvMethod(unittest.TestCase):
    def test_wifi_beacon_24(self) -> None:
        self.assertEqual(recv_method_from_sensor_type("WiFi Beacon 2.4"), constants.RECV_WIFI_BEACON_24)

    def test_bt_legacy(self) -> None:
        self.assertEqual(recv_method_from_sensor_type("Bluetooth legacy"), constants.RECV_BT_LEGACY)


class TestOdidMapper(unittest.TestCase):
    def test_minimal_required_fields(self) -> None:
        odid = {"BasicID": "1581F5YHX24BB002FUBN", "IDType": 1, "UAType": 2}
        mqtt = {"RSSI": -62, "type": "WiFi Beacon 2.4"}
        result = odid_to_dronehone_json(odid, mqtt)
        assert result is not None
        self.assertEqual(result["uasId"], "1581F5YHX24BB002FUBN")
        self.assertEqual(result["rssi"], -62)
        self.assertEqual(result["recvMethod"], constants.RECV_WIFI_BEACON_24)
        self.assertEqual(result["serialNumber"], "1581F5YHX24BB002FUBN")

    def test_missing_rssi_returns_none(self) -> None:
        odid = {"BasicID": "ABC123", "IDType": 1}
        self.assertIsNone(odid_to_dronehone_json(odid, {}))

    def test_full_kinematics(self) -> None:
        odid = {
            "BasicID": "UAS001",
            "IDType": 1,
            "UAType": 2,
            "Latitude": 37.7599566,
            "Longitude": -122.4983164,
            "AltitudeGeo": 212.0,
            "Direction": 126.0,
            "SpeedHorizontal": 12.75,
            "OperatorLatitude": 37.7599983,
            "OperatorLongitude": -122.4973975,
            "OperatorID": "OP123",
            "Status": 2,
            "Desc": "Recreational",
        }
        mqtt = {"RSSI": -55, "type": "WiFi Beacon 2.4"}
        result = odid_to_dronehone_json(odid, mqtt)
        assert result is not None
        self.assertAlmostEqual(result["uasLat"], 37.7599566)
        self.assertAlmostEqual(result["uasLon"], -122.4983164)
        self.assertEqual(result["uasHae"], 212.0)
        self.assertEqual(result["uasHeading"], 126.0)
        self.assertEqual(result["opId"], "OP123")
        self.assertEqual(result["description"], "Recreational")


if __name__ == "__main__":
    unittest.main()
