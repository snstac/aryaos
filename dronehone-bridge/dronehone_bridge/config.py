#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""Configuration loader for dronehone-bridge."""

from __future__ import annotations

import configparser
import os
import socket
from configparser import SectionProxy
from typing import Optional

import logging

from dronehone_bridge import constants


def load_config() -> SectionProxy:
    """Load configuration from defaults, ini, and environment."""
    config = configparser.ConfigParser()
    config.read_dict(
        {
            constants.APP_NAME: {
                "DEBUG": "false",
                "MQTT_BROKER": constants.DEFAULT_MQTT_BROKER,
                "MQTT_PORT": str(constants.DEFAULT_MQTT_PORT),
                "MQTT_TOPIC": constants.DEFAULT_MQTT_TOPIC,
                "MQTT_CLIENT_ID": f"dronehone-bridge_{socket.gethostname()}",
                "BT_ADAPTER": constants.DEFAULT_BT_ADAPTER,
                "BT_NAME": constants.DEFAULT_BT_NAME,
                "RFCOMM_CHANNEL": str(constants.DEFAULT_RFCOMM_CHANNEL),
                "RFCOMM_ENABLED": "true",
                "BLE_ENABLED": "false",
                "EMIT_INTERVAL_SEC": str(constants.DEFAULT_EMIT_INTERVAL_SEC),
                "UAS_STALE_SEC": str(constants.DEFAULT_UAS_STALE_SEC),
                "DEVICE_VERSION": constants.DEFAULT_DEVICE_VERSION,
                "DEVICE_MANUFACTURER": constants.DEFAULT_DEVICE_MANUFACTURER,
                "DEVICE_MAKE": constants.DEFAULT_DEVICE_MAKE,
                "DEVICE_SERIAL": "",
            }
        }
    )

    for path in ("/etc/dronehone-bridge.ini", "/etc/default/dronehone-bridge"):
        if os.path.isfile(path):
            config.read(path)

    section = config[constants.APP_NAME]
    _apply_env(section)
    return section


def _apply_env(section: SectionProxy) -> None:
    """Overlay environment variables (ARYAOS_* and DRONEHONE_BRIDGE_*)."""
    mapping = {
        "DEBUG": ("DEBUG", "DRONEHONE_BRIDGE_DEBUG"),
        "MQTT_BROKER": ("MQTT_BROKER", "DRONEHONE_BRIDGE_MQTT_BROKER"),
        "MQTT_PORT": ("MQTT_PORT", "DRONEHONE_BRIDGE_MQTT_PORT"),
        "MQTT_TOPIC": ("MQTT_TOPIC", "DRONEHONE_BRIDGE_MQTT_TOPIC"),
        "BT_ADAPTER": ("BT_ADAPTER", "DRONEHONE_BRIDGE_BT_ADAPTER"),
        "BT_NAME": ("BT_NAME", "DRONEHONE_BRIDGE_BT_NAME"),
        "RFCOMM_ENABLED": ("RFCOMM_ENABLED", "DRONEHONE_BRIDGE_RFCOMM_ENABLED"),
        "BLE_ENABLED": ("BLE_ENABLED", "DRONEHONE_BRIDGE_BLE_ENABLED"),
    }
    for key, env_keys in mapping.items():
        for env_key in env_keys:
            val = os.environ.get(env_key)
            if val is not None:
                section[key] = val
                break


def get_bool(section: SectionProxy, key: str, default: bool = False) -> bool:
    """Parse boolean config value."""
    raw = section.get(key, str(default)).strip().lower()
    return raw in {"1", "true", "yes", "on"}


def get_device_serial(section: SectionProxy) -> str:
    """Resolve sensor serial number for DeviceInfo JSON."""
    serial = section.get("DEVICE_SERIAL", "").strip()
    if serial:
        return serial
    try:
        with open("/proc/device-tree/serial-number", encoding="utf-8") as fh:
            return fh.read().strip("\x00\n ")
    except OSError:
        return socket.gethostname()


def device_info_dict(section: SectionProxy) -> dict:
    """Build DroneHone DeviceInfo JSON object."""
    info = {
        "version": section.get("DEVICE_VERSION", constants.DEFAULT_DEVICE_VERSION),
        "manufacturer": section.get(
            "DEVICE_MANUFACTURER", constants.DEFAULT_DEVICE_MANUFACTURER
        ),
        "make": section.get("DEVICE_MAKE", constants.DEFAULT_DEVICE_MAKE),
    }
    serial = get_device_serial(section)
    if serial:
        info["serialNumber"] = serial
    return info


def setup_logging(section: SectionProxy) -> None:
    """Configure application logging."""
    level = logging.DEBUG if get_bool(section, "DEBUG") else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )
