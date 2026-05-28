#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""Bluetooth Classic RFCOMM server for DroneHone external sensor protocol."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import socket
import subprocess
from configparser import SectionProxy
from typing import List, Optional, Set

from dronehone_bridge import constants
from dronehone_bridge.config import device_info_dict
from dronehone_bridge.hub import DetectionHub

logger = logging.getLogger(__name__)


class RfcommServer:
    """SPP/RFCOMM listener emitting newline-delimited DroneHone JSON."""

    def __init__(self, hub: DetectionHub, config: SectionProxy) -> None:
        self.hub = hub
        self.config = config
        self.adapter = config.get("BT_ADAPTER", constants.DEFAULT_BT_ADAPTER)
        self.channel = int(config.get("RFCOMM_CHANNEL", str(constants.DEFAULT_RFCOMM_CHANNEL)))
        self.emit_interval = float(
            config.get("EMIT_INTERVAL_SEC", str(constants.DEFAULT_EMIT_INTERVAL_SEC))
        )
        self.device_info = device_info_dict(config)
        self._clients: Set[socket.socket] = set()
        self._server_sock: Optional[socket.socket] = None
        self._running = False

    def adapter_address(self) -> str:
        """Read BD_ADDR for hci adapter."""
        path = f"/sys/class/bluetooth/{self.adapter}/address"
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()

    def setup_adapter(self) -> None:
        """Make adapter discoverable with friendly name for DroneHone discovery."""
        name = self.config.get("BT_NAME", constants.DEFAULT_BT_NAME)
        cmds = [
            ["bluetoothctl", "--timeout", "5", "system-alias", name],
            ["bluetoothctl", "--timeout", "5", "discoverable", "on"],
            ["bluetoothctl", "--timeout", "5", "pairable", "on"],
        ]
        for cmd in cmds:
            try:
                subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=10)
            except (subprocess.SubprocessError, FileNotFoundError) as exc:
                logger.warning("bluetoothctl %s failed: %s", cmd, exc)

        try:
            subprocess.run(
                ["sdptool", "add", "--channel", str(self.channel), "SP"],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
        except (subprocess.SubprocessError, FileNotFoundError) as exc:
            logger.warning("sdptool SP registration failed: %s", exc)

    def _bind_server(self) -> socket.socket:
        addr = self.adapter_address()
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((addr, self.channel))
        sock.listen(1)
        sock.setblocking(False)
        logger.info("RFCOMM listening on %s channel %d", addr, self.channel)
        return sock

    async def _accept_loop(self) -> None:
        assert self._server_sock is not None
        loop = asyncio.get_running_loop()
        while self._running:
            try:
                client, _peer = await loop.sock_accept(self._server_sock)
            except asyncio.CancelledError:
                raise
            except OSError as exc:
                logger.error("RFCOMM accept error: %s", exc)
                await asyncio.sleep(1)
                continue
            client.setblocking(False)
            self._clients.add(client)
            asyncio.create_task(self._client_session(client))

    async def _client_session(self, client: socket.socket) -> None:
        loop = asyncio.get_running_loop()
        info_line = (json.dumps(self.device_info, separators=(",", ":")) + "\n").encode()
        try:
            await loop.sock_sendall(client, info_line)
            logger.info("Sent DeviceInfo to DroneHone client")
            while self._running and client in self._clients:
                tracks = await self.hub.snapshot()
                if tracks:
                    for track in tracks:
                        line = json.dumps(track, separators=(",", ":")) + "\n"
                        await loop.sock_sendall(client, line.encode())
                else:
                    # Keepalive under 5 s watchdog when no aircraft
                    await loop.sock_sendall(
                        client,
                        (json.dumps({"batteryLevel": 1.0}) + "\n").encode(),
                    )
                await asyncio.sleep(self.emit_interval)
        except (OSError, asyncio.CancelledError) as exc:
            logger.info("RFCOMM client disconnected: %s", exc)
        finally:
            self._clients.discard(client)
            try:
                client.close()
            except OSError:
                pass

    async def _prune_loop(self) -> None:
        while self._running:
            await self.hub.prune()
            await asyncio.sleep(5)

    async def run(self) -> None:
        if not os.path.isdir(f"/sys/class/bluetooth/{self.adapter}"):
            raise RuntimeError(f"Bluetooth adapter not found: {self.adapter}")

        self.setup_adapter()
        self._running = True
        self._server_sock = self._bind_server()
        try:
            await asyncio.gather(
                self._accept_loop(),
                self._prune_loop(),
            )
        finally:
            self._running = False
            for client in list(self._clients):
                try:
                    client.close()
                except OSError:
                    pass
            self._clients.clear()
            if self._server_sock:
                self._server_sock.close()
