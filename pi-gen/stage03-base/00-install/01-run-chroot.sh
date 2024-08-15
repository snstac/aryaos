#!/bin/bash -e
# AryaOS 01-run-chroot.sh
#
# Establishes base configuration for AryaOS on the build image.
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


# RFC UUID
systemctl enable set_uuid
systemctl set-default multi-user


# Zerotier
/usr/local/sbin/install_zt.sh


# PyTAK
wget https://github.com/snstac/pytak/releases/latest/download/pytak_latest_all.deb
apt install -f ./pytak_latest_all.deb

wget https://github.com/snstac/takproto/releases/latest/download/takproto_latest_all.deb
apt install -f ./takproto_latest_all.deb

wget https://github.com/snstac/asyncinotify/releases/download/v4.0.9-4/python3-asyncinotify_4.0.9-1_all.deb
apt install -f ./python3-asyncinotify_4.0.9-1_all.deb

# Wireshark
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
echo "tshark-common tshark-common/install-setuid boolean true" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt install tshark -y
