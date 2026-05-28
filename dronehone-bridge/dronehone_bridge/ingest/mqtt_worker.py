#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""MQTT ingest worker — DroneScout protocol to DetectionHub."""

from __future__ import annotations

import base64
import json
import logging
from configparser import SectionProxy
from typing import Optional

import asyncio_mqtt as aiomqtt
import dronecot
import lzma

from dronehone_bridge.hub import DetectionHub
from dronehone_bridge.map.dronehone_json import odid_to_dronehone_json

logger = logging.getLogger(__name__)


class MQTTWorker:
    """Subscribe to DroneScout MQTT and push DroneHone JSON into the hub."""

    def __init__(self, hub: DetectionHub, config: SectionProxy) -> None:
        self.hub = hub
        self.config = config

    async def parse_message(self, message: aiomqtt.Message) -> None:
        payload = await self.decode_payload(message.payload)
        if not payload:
            return
        await self.process_payload(payload, message.topic.value)

    async def decode_payload(self, payload: bytes) -> Optional[str]:
        try:
            text = payload.decode()
            if text and ord(text[-1]) in {0, 10}:
                text = text[:-1]
            return text
        except (UnicodeDecodeError, AttributeError):
            pass
        try:
            text = lzma.decompress(payload).decode()
            if text and ord(text[-1]) == 0:
                text = text[:-1]
            return text
        except lzma.LZMAError as exc:
            logger.error("LZMA decompression error: %s", exc)
            return None

    async def process_payload(self, payload: str, topic: str) -> None:
        json_end = payload.find("}{")
        while True:
            chunk = payload[: json_end + 1] if json_end != -1 else payload
            if json_end != -1:
                payload = payload[json_end + 1 :]
            try:
                obj = json.loads(chunk)
            except json.JSONDecodeError as exc:
                logger.debug("JSON decode skip: %s", exc)
                return

            if obj.get("data"):
                await self.handle_sensor_data(obj, topic)
            elif "position" in topic:
                logger.debug("Sensor position on %s (ignored for DroneHone)", topic)

            if json_end == -1:
                break
            json_end = payload.find("}{")

    async def handle_sensor_data(self, message: dict, topic: str) -> None:
        if str(message.get("protocol", "")) != "1.0":
            return

        data = message.get("data") or {}
        uasdata_b64 = data.get("UASdata")
        if not uasdata_b64:
            return

        uasdata = base64.b64decode(uasdata_b64)
        valid_blocks = dronecot.decode_valid_blocks(uasdata, dronecot.ODIDValidBlocks())
        odid = dronecot.parse_payload(uasdata, valid_blocks)

        mqtt_meta = {k: v for k, v in data.items() if k != "UASdata"}
        odid["data"] = mqtt_meta
        odid["topic"] = topic
        odid["extra"] = message.get("extra") or {}

        mapped = odid_to_dronehone_json(odid, mqtt_meta)
        if mapped:
            await self.hub.update(mapped)
            logger.debug(
                "Hub update uasId=%s rssi=%s", mapped.get("uasId"), mapped.get("rssi")
            )

    async def run(self) -> None:
        broker = self.config.get("MQTT_BROKER", "localhost")
        port = int(self.config.get("MQTT_PORT", "1883"))
        topic = self.config.get("MQTT_TOPIC", "#")
        client_id = self.config.get("MQTT_CLIENT_ID", "dronehone-bridge")

        async with aiomqtt.Client(
            hostname=broker,
            port=port,
            client_id=client_id,
        ) as client:
            logger.info("MQTT connected %s:%s topic=%s", broker, port, topic)
            async with client.messages() as messages:
                await client.subscribe(topic)
                async for message in messages:
                    await self.parse_message(message)
