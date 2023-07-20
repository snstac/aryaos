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

# Captive portal / main page:
install -v -m 644 files/index.html	"${ROOTFS_DIR}/var/www/html/"
cp -r files/calfire_airbases	"${ROOTFS_DIR}/var/www/html/"
chmod +x "${ROOTFS_DIR}/var/www/html"

# Node-RED:
install -v -m 644 files/airtak-flows.json	"${ROOTFS_DIR}/home/node-red/.node-red/"
cat "${ROOTFS_DIR}/home/node-red/.node-red/airtak-flows.json" > "${ROOTFS_DIR}/home/node-red/.node-red/flows.json"
install -v -m 640 files/node-red.sudoers	"${ROOTFS_DIR}/etc/sudoers.d/node-red"
visudo -c "${ROOTFS_DIR}/etc/sudoers.d/node-red"
install -v -m 755 files/get_throttled.sh	"${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 755 files/wifi-nuke.py	"${ROOTFS_DIR}/usr/local/sbin/wifi-nuke.py"

# LINCOT tracker
install -v -m 644 files/lincot-config.txt	"${ROOTFS_DIR}/boot/"
install -v -m 755 files/run_lincot.sh	"${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/lincot.service	"${ROOTFS_DIR}/etc/systemd/system/"

# Set UUID on first boot
install -v -m 755 files/set_uuid.sh	"${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/set_uuid.service	"${ROOTFS_DIR}/etc/systemd/system/"

# AirTAK Env configuration
install -v -m 644 files/airtak-config.txt	"${ROOTFS_DIR}/boot/"
install -v -m 755 files/99-airtak-dispatcher "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -v -m 644 files/README-AirTAK.txt "${ROOTFS_DIR}/"
