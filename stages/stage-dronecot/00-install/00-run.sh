#!/bin/bash -e
# 00-run.sh
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

rsync -va "${SHARED_FILES}/dronecot/docker-uas-broker" "${ROOTFS_DIR}/usr/src/"
rsync -va "${SHARED_FILES}/dronecot/docker-uas-sensor" "${ROOTFS_DIR}/usr/src/"

# Script to reset wlan interfaces when restarting dronecot
# FIXME: Add to DroneCOT deb package installer.
install -v -m 755 "${SHARED_FILES}/dronecot/reset_wlan.sh" "${ROOTFS_DIR}/usr/local/sbin/"
mkdir -p "${ROOTFS_DIR}/etc/systemd/service/dronecot.service.d"
install -v -m 0644 "${SHARED_FILES}/dronecot/execprestart.conf" "${ROOTFS_DIR}/etc/systemd/service/dronecot.service.d"
