#!/bin/bash -e
# AryaOS 01-run-chroot.sh
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


# dump1090
DUMP1090_RECEIVER_SERIAL="stx:1090:0"
sed --follow-symlinks -i -E -e "s/RECEIVER_SERIAL.*/RECEIVER_SERIAL=$DUMP1090_RECEIVER_SERIAL/" /etc/default/dump1090-fa


# dump978
DUMP978_RECEIVER_SERIAL="stx:978:0"
sed --follow-symlinks -i -E -e "s/driver=rtlsdr /driver=rtlsdr,serial=$DUMP978_RECEIVER_SERIAL /" /etc/default/dump978-fa


# ADSBCOT
id adsbcot || useradd --system adsbcot
python3 -m pip install aircot --break-system-packages
python3 -m pip install adsbcot --break-system-packages


# readsb
# bash /home/pi/readsb-install.sh
dpkg -i /home/pi/readsb_3.14.1621_arm64.deb
cp /home/pi/readsb.service /lib/systemd/system/

# tar1090
bash /home/pi/tar1090-install.sh


# Disable everything
systemctl disable --now dump1090-fa &>/dev/null || true
systemctl disable --now dump978-fa &>/dev/null || true
systemctl disable --now ADSBCOT &>/dev/null || true
systemctl disable --now AryaAir &>/dev/null || true
systemctl disable --now readsb &>/dev/null || true
systemctl disable --now readsb-mutability &>/dev/null || true
systemctl disable --now dump1090-mutability &>/dev/null || true
systemctl disable --now dump1090 &>/dev/null || true
systemctl disable --now tar1090 &>/dev/null || true
systemctl disable --now skyaware &>/dev/null || true
