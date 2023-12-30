#!/bin/bash -e
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

python3 -m pip install lincot --break-system-packages

systemctl enable lincot
systemctl enable set_uuid

DUMP1090_RECEIVER_SERIAL="stx:1090:0"
sed --follow-symlinks -i -E -e "s/RECEIVER_SERIAL.*/RECEIVER_SERIAL=$DUMP1090_RECEIVER_SERIAL/" /etc/default/dump1090-fa

DUMP978_RECEIVER_SERIAL="stx:978:0" 
sed --follow-symlinks -i -E -e "s/driver=rtlsdr /driver=rtlsdr,serial=$DUMP978_RECEIVER_SERIAL /" /etc/default/dump978-fa

systemctl set-default multi-user

systemctl enable NetworkManager-dispatcher

sed --follow-symlinks -i -E -e "s/blank.org/airtak.local/" /usr/share/comitup/web/templates/connect.html

/usr/local/sbin/install_zt.sh

