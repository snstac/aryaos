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

sed --follow-symlinks -i -E -e "s/RECEIVER_SERIAL.*/RECEIVER_SERIAL=$DUMP1090_RECEIVER_SERIAL/" /etc/default/dump1090-fa
sed --follow-symlinks -i -E -e "s/driver=rtlsdr /driver=rtlsdr,serial=$DUMP978_RECEIVER_SERIAL /" /etc/default/dump978-fa

id adsbcot || useradd --system adsbcot

python3 -m pip install aircot --break-system-packages
python3 -m pip install adsbcot --break-system-packages

systemctl daemon-reload
systemctl disable dump1090-fa
systemctl disable dump978-fa
systemctl disable ADSBCOT
systemctl disable AryaAir