#!/bin/bash -e
# AryaOS run.sh
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


# Node-RED
install -v -m 755 "${SHARED_FILES}/node-red/update-nodejs-and-nodered" "${ROOTFS_DIR}/usr/src"
install -v -m 440 "${SHARED_FILES}/node-red/node-red.sudoers" "${ROOTFS_DIR}/etc/sudoers.d/node-red"
mkdir -p "${ROOTFS_DIR}/home/node-red/.node-red"
install -v -m 644 "${SHARED_FILES}/node-red/settings.js" "${ROOTFS_DIR}/home/node-red/.node-red/settings.js"
install -v -m 644 "${SHARED_FILES}/node-red/package.json"	"${ROOTFS_DIR}/home/node-red/.node-red/package.json"
install -v -m 644 "${SHARED_FILES}/node-red/aryaos_flows.json" "${ROOTFS_DIR}/home/node-red/.node-red/"
cat "${ROOTFS_DIR}/home/node-red/.node-red/aryaos_flows.json" > "${ROOTFS_DIR}/home/node-red/.node-red/flows.json"
