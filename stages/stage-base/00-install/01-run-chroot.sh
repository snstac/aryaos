#!/bin/bash -e
# 01-run-chroot.sh
#
# Establishes base configuration for base image.
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

# Tailscale
/usr/src/install_tailscale.sh


# Wireshark
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
echo "tshark-common tshark-common/install-setuid boolean true" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt install tshark -y

# Unattended builds: apt-listchanges otherwise shells out to `apt-get changelog` for many packages
# during export-image finalise (120s timeouts per package are common on slow mirrors).
if dpkg -s apt-listchanges >/dev/null 2>&1; then
	echo 'apt-listchanges apt-listchanges/frontend select none' | debconf-set-selections
	DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow apt-listchanges || true
fi
