#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""DroneHone bridge constants."""

APP_NAME = "dronehone-bridge"

# Bluetooth Classic SPP (DroneHone external sensor)
SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"
DEFAULT_RFCOMM_CHANNEL = 1

# BLE OpenDroneID (DroneHone internal scanner)
BLE_SERVICE_UUID = "0000fffa-0000-1000-8000-00805f9b34fb"
BLE_SERVICE_DATA_PREFIX = 0x0D

# DroneHone client timing (from BluetoothDeviceScanner.kt)
INFO_TIMEOUT_MS = 500
DATA_TIMEOUT_MS = 5000

# MQTT defaults (aligned with dronecot / DroneScout)
DEFAULT_MQTT_BROKER = "localhost"
DEFAULT_MQTT_PORT = 1883
DEFAULT_MQTT_TOPIC = "#"

DEFAULT_BT_ADAPTER = "hci0"
DEFAULT_BT_NAME = "AryaOS RemoteID"
DEFAULT_EMIT_INTERVAL_SEC = 1.0
DEFAULT_UAS_STALE_SEC = 30.0

DEFAULT_DEVICE_VERSION = "1.0.0"
DEFAULT_DEVICE_MANUFACTURER = "Sensors & Signals LLC"
DEFAULT_DEVICE_MAKE = "AryaOS"

# TransmissionMethod.fromCode (DroneHone)
RECV_WIFI_BEACON_24 = 1
RECV_WIFI_NAN_24 = 2
RECV_WIFI_BEACON_5 = 4
RECV_WIFI_NAN_5 = 8
RECV_BT_LEGACY = 16
RECV_BT_LONG_RANGE = 32
RECV_OTHER = 0
