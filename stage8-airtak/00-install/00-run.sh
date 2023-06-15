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

install -v -m 644 files/index.html	"${ROOTFS_DIR}/var/www/html/"
cp -r files/calfire_airbases	"${ROOTFS_DIR}/var/www/html/"
chmod +x "${ROOTFS_DIR}/var/www/html"
install -v -m 644 files/airtak-flows.json	"${ROOTFS_DIR}/home/node-red/.node-red/"
# saves having to set permissions & ownership again:
cat "${ROOTFS_DIR}/home/node-red/.node-red/airtak-flows.json" > "${ROOTFS_DIR}/home/node-red/.node-red/flows.json"

# Lincot tracker
install -v -m 644 files/lincot-main.zip	"${ROOTFS_DIR}/"

install -v -m 755 files/run_lincot.sh	"${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/lincot.ini	"${ROOTFS_DIR}/boot/"
install -v -m 644 files/lincot.service	"${ROOTFS_DIR}/etc/systemd/system/"
