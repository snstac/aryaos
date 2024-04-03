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

install -v -m 644 files/AryaAir.service     "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 755 files/enable_AryaAir.sh   "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/dump1090-fa.service "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 644 files/dump978-fa.service  "${ROOTFS_DIR}/lib/systemd/system/"

export APP_NAME="ADSBCOT"
install -v -m 644 "files/${APP_NAME}-config.txt"  "${ROOTFS_DIR}/boot/"
install -v -m 755 "files/run_${APP_NAME}.sh"      "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "files/${APP_NAME}.service"     "${ROOTFS_DIR}/lib/systemd/system/"
