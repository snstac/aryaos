#!/bin/bash
# AryaOS enable_AryaUAS.sh
#
# Enables AryaUAS services.
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

set -a
AOS_CONFIG="/boot/${AOS_FLAVOR:-AryaOS}-config.txt"

set +a
logger "Enabling AryaUAS services."
systemctl enable AryaUAS --now
systemctl enable DroneCOT --now
systemctl enable LINCOT --now

# cd /home/pi/docker-uas-broker
# docker compose up -d

# cd /home/pi/docker-uas-sensor
# docker compose up -d

# sed --follow-symlinks -i -E -e "s/flowFile:.*,/flowFile: 'AryaUAS_flows.json',/" /home/node-red/.node-red/settings.js