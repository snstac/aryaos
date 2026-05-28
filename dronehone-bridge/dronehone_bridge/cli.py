#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""CLI entrypoint."""

from __future__ import annotations

import asyncio
import logging
import signal

from dronehone_bridge import constants
from dronehone_bridge.config import get_bool, load_config, setup_logging
from dronehone_bridge.hub import DetectionHub
from dronehone_bridge.ingest.mqtt_worker import MQTTWorker
from dronehone_bridge.transport.ble_advertiser import BleAdvertiser
from dronehone_bridge.transport.rfcomm_server import RfcommServer

logger = logging.getLogger(constants.APP_NAME)


async def run_bridge() -> None:
    config = load_config()
    setup_logging(config)

    stale_sec = float(config.get("UAS_STALE_SEC", str(constants.DEFAULT_UAS_STALE_SEC)))
    hub = DetectionHub(stale_sec=stale_sec)

    tasks = []
    mqtt = MQTTWorker(hub, config)
    tasks.append(asyncio.create_task(mqtt.run(), name="mqtt"))

    if get_bool(config, "RFCOMM_ENABLED", True):
        rfcomm = RfcommServer(hub, config)
        tasks.append(asyncio.create_task(rfcomm.run(), name="rfcomm"))

    ble_advertiser = None
    if get_bool(config, "BLE_ENABLED", False):
        ble_advertiser = BleAdvertiser(hub, config)
        tasks.append(asyncio.create_task(ble_advertiser.run(), name="ble"))

    logger.info(
        "dronehone-bridge started (RFCOMM=%s BLE=%s)",
        get_bool(config, "RFCOMM_ENABLED", True),
        get_bool(config, "BLE_ENABLED", False),
    )

    stop = asyncio.Event()

    def _handle_signal(*_args) -> None:
        stop.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _handle_signal)
        except NotImplementedError:
            pass

    await stop.wait()
    for task in tasks:
        task.cancel()
    if ble_advertiser:
        ble_advertiser.stop()
    await asyncio.gather(*tasks, return_exceptions=True)
    logger.info("dronehone-bridge stopped")


def main() -> None:
    asyncio.run(run_bridge())


if __name__ == "__main__":
    main()
