#!/bin/bash -e
# AryaOS 00-run.sh
#
# Establishes base configuration for AryaOS on the build machine.
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

# SHARED_FILES should be set, if not, set it to ../shared_files
SHARED_FILES=${SHARED_FILES:-../shared_files}
pwd
ls ../
ls ../../

install -v -m 755 "${SHARED_FILES}/aryaos/get_throttled.sh" "${ROOTFS_DIR}/usr/local/sbin/"

# Set UUID on first boot
install -v -m 755 "${SHARED_FILES}/aryaos/set_uuid.sh"	      "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "${SHARED_FILES}/aryaos/set_uuid.service"  "${ROOTFS_DIR}/etc/systemd/system/"

# AryaOS Env configuration
install -v -m 644 "${SHARED_FILES}/aryaos/aryaos-config.txt"     "${ROOTFS_DIR}/etc/"
install -v -m 755 "${SHARED_FILES}/aryaos/99-aryaos-dispatcher"  "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -v -m 644 "${SHARED_FILES}/aryaos/README-aryaos.txt"     "${ROOTFS_DIR}/"

# ZeroTier
install -v -m 755 "${SHARED_FILES}/aryaos/install_zt.sh"     "${ROOTFS_DIR}/usr/local/sbin/"

# Required libraries
install -v -m 644 "${SHARED_FILES}/aryaos/python3-asyncinotify_4.0.9-1_all.deb"  "${ROOTFS_DIR}/home/pi/"
