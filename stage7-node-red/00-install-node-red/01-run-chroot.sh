#!/bin/bash -e
#
# Copyright 2023 Sensors & Signals LLC
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

adduser --disabled-password --gecos 'Node-RED Service User' node-red || exit 0
usermod -aG sudo node-red
bash /usr/local/sbin/update-nodejs-and-nodered --confirm-install --nodered-user=node-red --confirm-root --no-init

cd /home/node-red/.node-red
npm install node-red-contrib-tak
npm install node-red-contrib-web-worldmap

chown -R node-red:node-red /home/node-red

systemctl enable nodered
