#!/bin/bash -e
# AryaOS run-chroot.sh
#
# Node-RED intaller and setup script for AryaOS.
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

id node-red || adduser --disabled-password --gecos 'Node-RED Service User' node-red

# FIXME: I don't think this is required?
usermod -aG sudo node-red
# Let node-red see systemd logs:
usermod -aG adm node-red
# Let node-red get GPU stats:
usermod -aG video node-red
# Let node-red get SDR info:
usermod -aG plugdev node-red

chown -R node-red:node-red /home/node-red

# Install Node-RED using the node-red installer:
bash /usr/src/update-nodejs-and-nodered --confirm-install --nodered-user=node-red --confirm-root --no-init

# Install Node-RED pallet modules:
cd /home/node-red/.node-red
npm install

mkdir -p /home/node-red/tmpConf

chown -R node-red:node-red /home/node-red
chown -R node-red:node-red /var/www/html/recorder
chown -R node-red:node-red /etc/aryaos
chown -R node-red:node-red /var/www/html
chmod 0755 /var/www/html
chmod 0755 /var/www/html/recorder

chown node-red:node-red /etc/default/*cot

systemctl enable nodered
