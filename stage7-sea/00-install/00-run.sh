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

install -v -m 644 files/AryaSea.service "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 755 files/enable_AryaSea.sh "${ROOTFS_DIR}/usr/local/sbin"
install -v -m 644 "files/AryaSea_flows.json" "${ROOTFS_DIR}/home/node-red/.node-red"

install -v -m 755 files/uart_control "${ROOTFS_DIR}/home/pi"

mkdir -p "${ROOTFS_DIR}/usr/share/aiscatcher"

CONFIG="${ROOTFS_DIR}/boot/config.txt"
CMDLINE="${ROOTFS_DIR}/boot/cmdline.txt"

sed -i $CMDLINE -e "s/console=ttyAMA0,[0-9]\+ //"
sed -i $CMDLINE -e "s/console=serial0,[0-9]\+ //"

is_pithree() {
   grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[8d][0-9a-fA-F]$" /proc/cpuinfo
   return $?
}

if is_pithree; then
  sed $CONFIG -i -e "s/^#dtoverlay=pi3-disable-bt/dtoverlay=pi3-disable-bt/"
else
  sed $CONFIG -i -e "s/^#dtoverlay=disable-bt/dtoverlay=disable-bt/"
fi

APP_NAME="AISCOT"
install -v -m 644 files/${APP_NAME}-config.txt "${ROOTFS_DIR}/boot/"
install -v -m 644 files/${APP_NAME}.service	   "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 755 files/run_${APP_NAME}.sh     "${ROOTFS_DIR}/usr/local/sbin/"

APP_NAME="aiscatcher"
install -v -m 644 files/${APP_NAME}.conf    "${ROOTFS_DIR}/etc/"
install -v -m 644 files/${APP_NAME}.service	"${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 755 files/run_${APP_NAME}.sh  "${ROOTFS_DIR}/usr/local/sbin/"
