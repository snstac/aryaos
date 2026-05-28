#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""Map Open Drone ID / DroneScout MQTT data to DroneHone JSON lines."""

from __future__ import annotations

import math
from typing import Any, Optional

from dronehone_bridge import constants


def _is_nan(value: Any) -> bool:
    try:
        return math.isnan(float(value))
    except (TypeError, ValueError):
        return True


def _clean_float(value: Any) -> Optional[float]:
    if value is None or _is_nan(value):
        return None
    return float(value)


def recv_method_from_sensor_type(sensor_type: Any) -> int:
    """Map DroneScout MQTT data.type string to DroneHone recvMethod code."""
    if sensor_type is None:
        return constants.RECV_OTHER
    text = str(sensor_type).lower()
    if "bluetooth" in text or "ble" in text or "bt " in text:
        if "long" in text or "coded" in text:
            return constants.RECV_BT_LONG_RANGE
        return constants.RECV_BT_LEGACY
    if "5" in text and ("wifi" in text or "wlan" in text):
        if "nan" in text:
            return constants.RECV_WIFI_NAN_5
        return constants.RECV_WIFI_BEACON_5
    if "nan" in text:
        return constants.RECV_WIFI_NAN_24
    if "wifi" in text or "wlan" in text or "beacon" in text:
        return constants.RECV_WIFI_BEACON_24
    return constants.RECV_OTHER


def _primary_uas_id(odid: dict) -> Optional[str]:
    basic_id = odid.get("BasicID")
    if isinstance(basic_id, tuple):
        basic_id = basic_id[0] if basic_id else None
    if isinstance(basic_id, str) and basic_id.strip():
        return basic_id.strip()
    return None


def _id_type_fields(odid: dict, uas_id: str) -> dict:
    """Set serialNumber/remoteId/etc. based on IDType."""
    id_type = odid.get("IDType")
    fields: dict[str, str] = {}
    if id_type == 1:
        fields["serialNumber"] = uas_id
    elif id_type == 2:
        fields["remoteId"] = uas_id
    elif id_type == 3:
        fields["utmId"] = uas_id
    elif id_type == 4:
        fields["caaRegId"] = uas_id
    elif id_type == 5:
        fields["sessionId"] = uas_id
    return fields


def odid_to_dronehone_json(odid: dict, mqtt_data: Optional[dict] = None) -> Optional[dict]:
    """
    Convert parsed ODID dict (+ optional DroneScout metadata) to DroneHone UAS JSON.

    Returns None when required fields are missing.
    """
    mqtt_data = mqtt_data or odid.get("data") or {}
    if isinstance(mqtt_data, dict) and "data" in odid and odid.get("data") is mqtt_data:
        pass

    uas_id = _primary_uas_id(odid)
    if not uas_id:
        return None

    rssi_raw = mqtt_data.get("RSSI")
    if rssi_raw is None:
        rssi_raw = odid.get("extra", {}).get("rssi") if isinstance(odid.get("extra"), dict) else None
    try:
        rssi = int(rssi_raw)
    except (TypeError, ValueError):
        return None

    recv_method = recv_method_from_sensor_type(
        mqtt_data.get("type") or mqtt_data.get("interface")
    )

    msg: dict[str, Any] = {
        "uasId": uas_id,
        "rssi": rssi,
        "recvMethod": recv_method,
    }
    msg.update(_id_type_fields(odid, uas_id))

    ua_type = odid.get("UAType")
    if ua_type is not None:
        try:
            msg["uasType"] = int(ua_type)
        except (TypeError, ValueError):
            pass

    lat = _clean_float(odid.get("Latitude"))
    lon = _clean_float(odid.get("Longitude"))
    if lat is not None and lon is not None:
        msg["uasLat"] = lat
        msg["uasLon"] = lon

    hae = _clean_float(odid.get("AltitudeGeo"))
    if hae is not None:
        msg["uasHae"] = hae

    heading = _clean_float(odid.get("Direction"))
    if heading is not None:
        msg["uasHeading"] = heading

    height = _clean_float(odid.get("Height"))
    height_type = odid.get("HeightType")
    if height is not None:
        if height_type == 0:
            msg["uasHag"] = height
        elif height_type == 1:
            msg["uasHat"] = height

    h_speed = _clean_float(odid.get("SpeedHorizontal"))
    if h_speed is not None:
        msg["uasHSpeed"] = h_speed

    v_speed = _clean_float(odid.get("SpeedVertical"))
    if v_speed is not None:
        msg["uasVSpeed"] = v_speed

    op_lat = _clean_float(odid.get("OperatorLatitude"))
    op_lon = _clean_float(odid.get("OperatorLongitude"))
    if op_lat is not None and op_lon is not None:
        msg["opLat"] = op_lat
        msg["opLon"] = op_lon

    op_hae = _clean_float(odid.get("OperatorAltitudeGeo"))
    if op_hae is not None:
        msg["opHae"] = op_hae

    op_id = odid.get("OperatorID")
    if isinstance(op_id, str) and op_id.strip():
        msg["opId"] = op_id.strip()

    op_loc_type = odid.get("OperatorLocationType")
    if op_loc_type is not None:
        try:
            msg["opLocationType"] = int(op_loc_type)
        except (TypeError, ValueError):
            pass

    status = odid.get("Status")
    if status is not None:
        try:
            msg["opStatus"] = int(status)
        except (TypeError, ValueError):
            pass

    desc = odid.get("Desc")
    if isinstance(desc, str) and desc.strip():
        msg["description"] = desc.strip()

    return msg
