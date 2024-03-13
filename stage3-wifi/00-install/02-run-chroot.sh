#!/bin/bash -e
# AryaOS 02-run-chroot.sh
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

# FIXME: Remove when fix is merged to NetworManager
# Apply fix to NetworkManager.
unzip -o /home/pi/python-networkmanager-main.zip
cp python-networkmanager-main/NetworkManager.py /usr/lib/python3/dist-packages/NetworkManager.py

systemctl enable NetworkManager