#!/usr/bin/env python3
# AryaOS wifi-nuke.py
#
# CLI to nuke WiFi connections.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import sys

sys.path.append("/usr/share/comitup")

from comitup import client as ciu


def get_state(ciu_client):
    state, connection = ciu_client.ciu_state()
    return state, connection


def nuke(ciu_client):
    state, connection = get_state(ciu_client)
    if "HOTSPOT" not in state:
        print(f"Deleting {connection}")
        ciu_client.ciu_delete(connection)


if __name__ == "__main__":
    ciu_client = ciu.CiuClient()
    nuke(ciu_client)
