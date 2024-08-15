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

install -v -m 755 files/99-aryaos-recorder.conf           "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"

# dump1090-fa
install -v -m 644 files/dump1090-fa.service           "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 644 files/dump978-fa.service            "${ROOTFS_DIR}/lib/systemd/system/"

# readsb
install -v -m 755 files/readsb-install.sh          "${ROOTFS_DIR}/home/pi/"
install -v -m 755 files/tar1090-install.sh         "${ROOTFS_DIR}/home/pi/"
install -v -m 755 files/readsb-set-location.sh     "${ROOTFS_DIR}/usr/local/bin/"
install -v -m 755 files/readsb-gain.sh             "${ROOTFS_DIR}/usr/local/bin/"
install -v -m 755 files/run_readsb.sh              "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/readsb_3.14.1621_arm64.deb "${ROOTFS_DIR}/home/pi/"

install -v -m 755 files/89-skyaware.conf           "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"
