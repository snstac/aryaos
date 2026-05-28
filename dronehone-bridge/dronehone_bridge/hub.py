#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# SPDX-License-Identifier: Apache-2.0

"""In-memory hub of active UAS detections for Bluetooth export."""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional


@dataclass
class TrackedUas:
    """One aircraft track keyed by uasId."""

    uas_id: str
    payload: dict
    updated_at: float = field(default_factory=time.monotonic)


class DetectionHub:
    """Thread-safe async hub of latest DroneHone JSON per UAS."""

    def __init__(self, stale_sec: float = 30.0) -> None:
        self.stale_sec = stale_sec
        self._tracks: Dict[str, TrackedUas] = {}
        self._lock = asyncio.Lock()
        self._listeners: List[Callable[[], None]] = []

    def add_listener(self, callback: Callable[[], None]) -> None:
        self._listeners.append(callback)

    async def update(self, payload: dict) -> None:
        uas_id = payload.get("uasId")
        if not uas_id:
            return
        async with self._lock:
            self._tracks[uas_id] = TrackedUas(uas_id=uas_id, payload=dict(payload))
        for listener in self._listeners:
            listener()

    async def snapshot(self) -> List[dict]:
        """Return non-stale UAS payloads."""
        now = time.monotonic()
        async with self._lock:
            active = [
                track.payload
                for track in self._tracks.values()
                if now - track.updated_at <= self.stale_sec
            ]
        return active

    async def prune(self) -> None:
        """Remove stale tracks."""
        now = time.monotonic()
        async with self._lock:
            stale_keys = [
                key
                for key, track in self._tracks.items()
                if now - track.updated_at > self.stale_sec
            ]
            for key in stale_keys:
                del self._tracks[key]
