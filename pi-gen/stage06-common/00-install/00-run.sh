#!/bin/bash -e
# AryaOS 00-run.sh
# OS customizations: captive portal, Node-RED flows, sudo, lincot.
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

# Don't try to restart 'comitup' here. Don't add it to this list.
# Trust me - gba@2024
AOS_SERVICES="readsb dump1090-fa dump978-fa tar1090 dump1090 dump1090-mutability gpsd aiscatcher nodered aiscot lincot adsbcot dronecot adsbxcot aprscot spotcot"

function gen_aos_service_sudoers() {
    SERVICES=${1:-$AOS_SERVICES}
    for srv in ${SERVICES}; do
        echo "# Start commands for: ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl disable ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl enable ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl disable ${srv} --now"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl enable ${srv} --now"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl start ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl stop ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl restart ${srv}"
        echo "node-red ALL=(root) NOPASSWD: /bin/systemctl status ${srv}"
        echo "# End commands for: ${srv}"
    done
}


# Lighttpd: Captive portal / main page
mkdir -p "${ROOTFS_DIR}/var/www/"
rsync -va files/html/ "${ROOTFS_DIR}/var/www/html/"
rsync -va files/calfire_airbases/ "${ROOTFS_DIR}/var/www/html/calfire_airbases/"
chmod +x "${ROOTFS_DIR}/var/www/html"
# FIXME For logs recorder directory listing, currently 403's.
#       https://redmine.lighttpd.net/projects/lighttpd/wiki/Mod_dirlisting 


# WiFi: Python tool to clear WiFi secrets.
install -v -m 755 files/wifi-nuke.py	"${ROOTFS_DIR}/usr/local/sbin/wifi-nuke.py"


# Node-RED
install -v -m 644 files/aryaos_flows.json	"${ROOTFS_DIR}/home/node-red/.node-red/"
cat "${ROOTFS_DIR}/home/node-red/.node-red/aryaos_flows.json" > "${ROOTFS_DIR}/home/node-red/.node-red/flows.json"
install -v -m 640 files/node-red.sudoers "${ROOTFS_DIR}/etc/sudoers.d/node-red"


# Customize sudo
gen_aos_service_sudoers "${AOS_SERVICES}" >> "${ROOTFS_DIR}/etc/sudoers.d/aryaos-services"
install -v -m 644 files/aryaos.sudoers "${ROOTFS_DIR}/etc/sudoers.d/aryaos"

# FIXME: Disabled to work-around https://github.com/snstac/aryaos/issues/56
# Verify sudoers file:
# visudo -c "${ROOTFS_DIR}/etc/sudoers.d/node-red"


# lincot tracker
install -v -m 644 files/lincot.service      "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 755 files/run_lincot.sh       "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 files/lincot-config.txt   "${ROOTFS_DIR}/etc/"
install -v -m 755 files/get_position.sh     "${ROOTFS_DIR}/usr/local/bin/"
