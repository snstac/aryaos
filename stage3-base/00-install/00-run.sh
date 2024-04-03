#!/bin/bash -e
# AryaOS 00-run.sh
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

install -v -m 755 files/get_throttled.sh "${ROOTFS_DIR}/usr/local/sbin/"

# Set UUID on first boot
install -v -m 755 files/set_UUID.sh	      "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/set_UUID.service  "${ROOTFS_DIR}/etc/systemd/system/"

# AryaOS Env configuration
install -v -m 644 "files/${AOS_FLAVOR:-AryaOS}-config.txt" "${ROOTFS_DIR}/boot/"
install -v -m 755 files/99-AryaOS-Dispatcher     "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -v -m 644 files/README-AryaOS.txt        "${ROOTFS_DIR}/"

# ZeroTier
install -v -m 755 files/install_ZT.sh     "${ROOTFS_DIR}/usr/local/sbin/"
