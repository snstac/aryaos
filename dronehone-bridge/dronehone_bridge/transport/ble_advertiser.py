#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""BLE OpenDroneID advertiser for DroneHone internal scanner path."""

from __future__ import annotations

import asyncio
import logging
import struct
from configparser import SectionProxy
from typing import Dict, List, Optional

from dronehone_bridge import constants
from dronehone_bridge.hub import DetectionHub

logger = logging.getLogger(__name__)

# ASTM F3411 message type high nibble
_MSG_BASIC_ID = 0x0
_MSG_LOCATION = 0x1
_MSG_MESSAGE_PACK = 0xF

_ODID_MSG_SIZE = 0x19


def _encode_lat_lon(value: float) -> bytes:
    """Encode WGS84 coordinate as ODID int32 LE (value * 1e7)."""
    encoded = int(round(value * 1e7))
    encoded = max(min(encoded, 1800000000), -1800000000)
    return struct.pack("<i", encoded)


def _encode_altitude(value: float) -> bytes:
    """Encode altitude metres as ODID uint16 LE ((alt + 1000) * 2)."""
    if value < -1000:
        return struct.pack("<H", 0)
    enc = int(round((value + 1000.0) * 2.0))
    enc = max(min(enc, 65535), 0)
    return struct.pack("<H", enc)


def _encode_speed(value: float) -> int:
    """Encode speed to ODID byte (0.25 m/s steps, cap 255)."""
    steps = int(round(value / 0.25))
    return max(min(steps, 255), 0)


def encode_basic_id(uas_id: str, ua_type: int = 2, id_type: int = 1) -> bytes:
    """Build 25-byte BASIC_ID OpenDroneID message."""
    buf = bytearray(25)
    buf[0] = (_MSG_BASIC_ID << 4) | 0x2  # type + version
    buf[1] = ((id_type & 0xF) << 4) | (ua_type & 0xF)
    uid = uas_id.encode("ascii", errors="ignore")[:20]
    buf[2 : 2 + len(uid)] = uid
    return bytes(buf)


def encode_location_vector(track: dict) -> Optional[bytes]:
    """Build 25-byte LOCATION_VECTOR message from DroneHone JSON track."""
    lat = track.get("uasLat")
    lon = track.get("uasLon")
    if lat is None or lon is None:
        return None

    buf = bytearray(25)
    op_status = int(track.get("opStatus", 2))
    buf[0] = (_MSG_LOCATION << 4) | 0x2
    buf[1] = (op_status & 0xF) << 4

    heading = int(track.get("uasHeading", 0)) % 360
    buf[2] = heading & 0xFF

    h_speed = track.get("uasHSpeed", 0.0) or 0.0
    v_speed = track.get("uasVSpeed", 0.0) or 0.0
    buf[3] = _encode_speed(float(h_speed))
    buf[4] = _encode_speed(abs(float(v_speed)))

    buf[5:9] = _encode_lat_lon(float(lat))
    buf[9:13] = _encode_lat_lon(float(lon))
    # pressure altitude unused (13:15)
    hae = track.get("uasHae")
    if hae is not None:
        buf[15:17] = _encode_altitude(float(hae))
    hag = track.get("uasHag")
    if hag is not None:
        buf[17:19] = _encode_altitude(float(hag))

    return bytes(buf)


def build_message_pack(messages: List[bytes]) -> bytes:
    """Wrap sub-messages in MESSAGE_PACK (0xF) for BLE advertisement."""
    pack = bytearray()
    pack.append((_MSG_MESSAGE_PACK << 4) | 0x2)
    pack.append(_ODID_MSG_SIZE)
    pack.append(len(messages))
    for msg in messages:
        if len(msg) != _ODID_MSG_SIZE:
            padded = msg.ljust(_ODID_MSG_SIZE, b"\x00")
        else:
            padded = msg
        pack.extend(padded)
    return bytes(pack)


class BleAdvertiser:
    """Rotate BLE advertisements with OpenDroneID service data for DroneHone."""

    def __init__(self, hub: DetectionHub, config: SectionProxy) -> None:
        self.hub = hub
        self.config = config
        self.adapter = config.get("BT_ADAPTER", constants.DEFAULT_BT_ADAPTER)
        self.interval = float(config.get("EMIT_INTERVAL_SEC", "0.5"))
        self._index = 0
        self._running = False

    def _build_adv_bytes(self, track: dict) -> Optional[bytes]:
        uas_id = track.get("uasId")
        if not uas_id:
            return None
        msgs: List[bytes] = [encode_basic_id(str(uas_id), int(track.get("uasType", 2)))]
        loc = encode_location_vector(track)
        if loc:
            msgs.append(loc)
        if len(msgs) == 1:
            return msgs[0]
        return build_message_pack(msgs)

    async def _advertise_once(self, payload: bytes) -> None:
        """Publish one LE advertisement via bluetoothctl mgmt interface."""
        # Service data: 0x0D prefix + ODID payload (DroneHone filter)
        service_data = bytes([constants.BLE_SERVICE_DATA_PREFIX]) + payload
        hex_data = service_data.hex()
        uuid = constants.BLE_SERVICE_UUID

        cmd = [
            "bluetoothctl",
            "--timeout",
            "10",
            "advertise",
            "on",
            "name",
            self.config.get("BT_NAME", constants.DEFAULT_BT_NAME),
            "service",
            uuid,
            "data",
            hex_data,
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _stdout, stderr = await proc.communicate()
        if proc.returncode != 0:
            logger.debug("bluetoothctl advertise: %s", stderr.decode(errors="replace"))

    async def run(self) -> None:
        self._running = True
        logger.info("BLE advertiser started on %s", self.adapter)
        while self._running:
            tracks = await self.hub.snapshot()
            if not tracks:
                await asyncio.sleep(self.interval)
                continue

            track = tracks[self._index % len(tracks)]
            self._index += 1
            payload = self._build_adv_bytes(track)
            if payload:
                try:
                    await self._advertise_once(payload)
                except OSError as exc:
                    logger.warning("BLE advertise failed: %s", exc)
            await asyncio.sleep(self.interval)

    def stop(self) -> None:
        self._running = False
