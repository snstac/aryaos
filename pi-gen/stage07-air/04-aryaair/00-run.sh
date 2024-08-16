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

install -v -m 755 "${SHARED_FILES}/aryaos/99-aryaos-recorder.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"

# dump1090-fa
install -v -m 644 "${SHARED_FILES}/air/dump1090-fa.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 644 "${SHARED_FILES}/air/dump978-fa.service" "${ROOTFS_DIR}/lib/systemd/system/"

# readsb
install -v -m 755 "${SHARED_FILES}/air/readsb-install.sh" "${ROOTFS_DIR}/usr/src/"
install -v -m 755 "${SHARED_FILES}/air/tar1090-install.sh" "${ROOTFS_DIR}/usr/src/"

install -v -m 755 "${SHARED_FILES}/air/readsb-set-location.sh" "${ROOTFS_DIR}/usr/local/bin/"
install -v -m 755 "${SHARED_FILES}/air/readsb-gain.sh" "${ROOTFS_DIR}/usr/local/bin/"
install -v -m 755 "${SHARED_FILES}/air/run_readsb.sh" "${ROOTFS_DIR}/usr/local/sbin/"

install -v -m 644 "${SHARED_FILES}/air/readsb_3.14.1621_arm64.deb" "${ROOTFS_DIR}/usr/src/"

install -v -m 755 "${SHARED_FILES}/air/89-skyaware.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"
