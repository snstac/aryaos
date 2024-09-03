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

# common
install -v -m 755 "${SHARED_FILES}/adsbcot/89-skyaware.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"
install -v -m 644 "${SHARED_FILES}/adsbcot/osmocom-rtl-sdr.rules" "${ROOTFS_DIR}/etc/udev/rules.d/"
install -v -m 600 "${SHARED_FILES}/adsbcot/blacklist-rtl-sdr.conf"	"${ROOTFS_DIR}/etc/modprobe.d/"
install -v -m 755 "${SHARED_FILES}/adsbcot/tar1090-install.sh" "${ROOTFS_DIR}/usr/src/"

# dump1090-fa
install -v -m 644 "${SHARED_FILES}/adsbcot/dump1090-fa.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 644 "${SHARED_FILES}/adsbcot/dump978-fa.service" "${ROOTFS_DIR}/lib/systemd/system/"


# readsb
install -v -m 644 "${SHARED_FILES}/adsbcot/readsb_3.14.1621_arm64.deb" "${ROOTFS_DIR}/usr/src/"
install -v -m 755 "${SHARED_FILES}/adsbcot/readsb-install.sh" "${ROOTFS_DIR}/usr/src/"
install -v -m 755 "${SHARED_FILES}/adsbcot/run_readsb.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "${SHARED_FILES}/adsbcot/readsb.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 755 "${SHARED_FILES}/adsbcot/readsb-set-location.sh" "${ROOTFS_DIR}/usr/local/bin/"
install -v -m 755 "${SHARED_FILES}/adsbcot/readsb-gain.sh" "${ROOTFS_DIR}/usr/local/bin/"
