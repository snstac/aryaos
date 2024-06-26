#!/bin/bash -e
# AryaOS 01-run-chroot.sh
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

python3 -m pip install lincot --break-system-packages

systemctl enable NetworkManager-dispatcher

id lincot || useradd --system lincot

sed --follow-symlinks -i -E -e "s/blank.org/aryaos.local/" /usr/share/comitup/web/templates/connect.html
# sed --follow-symlinks -i -E -e "s/aryaos.local/${AT_FLAVOR}.local/" /var/www/html/index.html

# sed --follow-symlinks -i -E -e "s/flows.json/AryaOS_flows.json/" /home/node-red/.node-red/settings.js

#sed --follow-symlinks -i -E -e "s/flowFile:.*,/flowFile: 'AryaOS_flows.json',/" /home/node-red/.node-red/settings.js

mkdir -p /var/www/html/logs
chown node-red /var/www/html/logs
