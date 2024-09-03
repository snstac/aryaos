#!/bin/bash -e
# 00-run.sh
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
# SHARED_FILES=${SHARED_FILES:-../../shared_files}


# Common

## Copy the AryaOS banner files to /etc/
install -v -m 0644 "${SHARED_FILES}/aryaos/motd" "${ROOTFS_DIR}/etc/motd"
install -v -m 0644 "${SHARED_FILES}/aryaos/issue" "${ROOTFS_DIR}/etc/issue"
install -v -m 0644 "${SHARED_FILES}/aryaos/issue.net" "${ROOTFS_DIR}/etc/issue.net"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-release" "${ROOTFS_DIR}/etc/aryaos-release"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-version" "${ROOTFS_DIR}/etc/aryaos-version"
install -v -m 0644 "${SHARED_FILES}/aryaos/README-aryaos.txt" "${ROOTFS_DIR}/"

## Copy the AryaOS sudoers file to /etc/sudoers.d/aryaos
install -v -m 0400 "${SHARED_FILES}/aryaos/aryaos.sudoers" "${ROOTFS_DIR}/etc/sudoers.d/aryaos"

## Copy the AryaOS configuration file to /etc/aryaos/
mkdir -p "${ROOTFS_DIR}/etc/aryaos/"
install -v -m 0644 "${SHARED_FILES}/aryaos/aryaos-config.txt" "${ROOTFS_DIR}/etc/aryaos/"

## Get throttled status on Raspberry Pi
install -v -m 0755 "${SHARED_FILES}/aryaos/get_throttled.sh" "${ROOTFS_DIR}/usr/local/sbin/"

## Set the GPS device to /dev/ttyUSB0
## FIXME Magic number /dev/ttyUSB0
sed --follow-symlinks -i -E -e "s/DEVICES=\".*\"/DEVICES=\"\/dev\/ttyUSB0\"/" "${ROOTFS_DIR}/etc/default/gpsd"


# UUID

## Set UUID on first boot
install -v -m 0755 "${SHARED_FILES}/aryaos/set_uuid.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 0644 "${SHARED_FILES}/aryaos/set_uuid.service" "${ROOTFS_DIR}/etc/systemd/system/"


# Portal

mkdir -p "${ROOTFS_DIR}/var/www/"

rsync -va "${SHARED_FILES}/aryaos/html/" "${ROOTFS_DIR}/var/www/html/"
chmod 0655 "${ROOTFS_DIR}/var/www/html"

rsync -va "${SHARED_FILES}/aryaos/calfire_airbases/" "${ROOTFS_DIR}/var/www/html/calfire_airbases/"


# Recorder

## Copy Recorder configuration files to lighttpd conf-available
install -v -m 0644 "${SHARED_FILES}/aryaos/99-aryaos-recorder.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-available/"

## Symlink Recorder configuration files to lighttpd conf-enabled
ln -sf /etc/lighttpd/conf-available/99-aryaos-recorder.conf "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/99-aryaos-recorder.conf"
## FIXME Deprecated hard-copy of 99-aryaos-recorder.conf
## install -v -m 755 "${SHARED_FILES}/aryaos/99-aryaos-recorder.conf" "${ROOTFS_DIR}/etc/lighttpd/conf-enabled/"


# WiFi

install -v -m 755 "${SHARED_FILES}/aryaos/99-aryaos-dispatcher" "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -v -m 644 "${SHARED_FILES}/aryaos/comitup.conf" "${ROOTFS_DIR}/etc/"
install -v -m 755 "${SHARED_FILES}/aryaos/run_comitup.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 755 "${SHARED_FILES}/aryaos/comitup-callback.sh" "${ROOTFS_DIR}/usr/local/sbin/"
install -v -m 644 "${SHARED_FILES}/aryaos/comitup.service" "${ROOTFS_DIR}/lib/systemd/system/"
install -v -m 644 "${SHARED_FILES}/aryaos/comitup.json" "${ROOTFS_DIR}/var/lib/comitup/"
install -v -m 755 "${SHARED_FILES}/aryaos/wifi-nuke.py" "${ROOTFS_DIR}/usr/local/sbin/"
## FIXME Deprecated replace old NetworkManager Python module. https://github.com/snstac/aryaos/issues/54 
install -v -m 644 "${SHARED_FILES}/aryaos/NetworkManager.py" "${ROOTFS_DIR}/usr/lib/python3/dist-packages/NetworkManager.py"

## Remove the string ;http://blank.org/ from the connect.html file.
sed --follow-symlinks -i -E -e "s/;http:\/\/blank.org\///" "${ROOTFS_DIR}/usr/share/comitup/web/templates/connect.html"

## Replace default comitup port 80 with 9080
sed --follow-symlinks -i -E -e "s/port=80/port=9080/" "${ROOTFS_DIR}/usr/share/comitup/web/comitupweb.py"
## TODO Add support for main branch of comitup, which uses a different syntax for port configuration.
## sed --follow-symlinks -i -E -e "s/SERVER_PORT = 80/SERVER_PORT = ${COMITUP_WEB_PORT}/" /usr/share/comitup/web/comitupweb.py


# lincot
install -v -m 755 "${SHARED_FILES}/aryaos/get_position.sh" "${ROOTFS_DIR}/usr/local/bin/"
