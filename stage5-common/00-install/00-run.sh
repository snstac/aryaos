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

function gen_aos_service_sudoers() {
    SERVICES=${1:-$AOS_SERVICES}
    for srv in ${SERVICES}; do
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl disable ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl enable ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl start ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl stop ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl restart ${srv}"
    done
}

# Captive portal / main page
mkdir -p "${ROOTFS_DIR}/var/www/"
rsync -va files/html/ "${ROOTFS_DIR}/var/www/"
rsync -va files/calfire_airbases/ "${ROOTFS_DIR}/var/www/html/"
chmod +x "${ROOTFS_DIR}/var/www/html"

install -v -m 755 files/wifi-nuke.py	"${ROOTFS_DIR}/usr/local/sbin/wifi-nuke.py"

# Node-RED
install -v -m 644 files/aryaos-flows.json	"${ROOTFS_DIR}/home/node-red/.node-red/"
cat "${ROOTFS_DIR}/home/node-red/.node-red/aryaos-flows.json" > "${ROOTFS_DIR}/home/node-red/.node-red/flows.json"

install -v -m 640 files/node-red.sudoers "${ROOTFS_DIR}/etc/sudoers.d/node-red"
SUDO_SERVICES="dump1090-fa dump978-fa gpsd comitup ${AOS_SERVICES}"
gen_aos_service_sudoers "${SUDO_SERVICES}" >> "${ROOTFS_DIR}/etc/sudoers.d/node-red"

# FIXME: Disabled to work-around https://github.com/snstac/aryaos/issues/56
# visudo -c "${ROOTFS_DIR}/etc/sudoers.d/node-red"

# LINCOT tracker
install -v -m 755 files/get_position.sh         "${ROOTFS_DIR}/usr/local/bin/"

id lincot || useradd --system lincot

export APP_NAME="LINCOT"
install -v -m 644 "files/${APP_NAME}-config.txt" "${ROOTFS_DIR}/boot/"
install -v -m 755 "files/run_${APP_NAME}.sh"     "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "files/${APP_NAME}.service"     "${ROOTFS_DIR}/lib/systemd/system/"
