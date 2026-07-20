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


# The AryaOS overlay deb is built into /usr/src by stage-aryaos/00-run.sh but
# INSTALLED in stage-pytak/00-install/01-run-chroot.sh: it Depends on pytak,
# which only becomes installable once stage-pytak configures the snstac apt
# repo. Legacy file copies remain in 00-run.sh for now as a fallback.

# RFC UUID
systemctl enable aryaos-firstboot
systemctl set-default multi-user

systemctl enable NetworkManager
systemctl enable NetworkManager-dispatcher

systemctl enable cockpit.socket
systemctl enable lighttpd

# Hardening: firewall + SSH brute-force protection. unattended-upgrades runs
# via the static apt-daily timers; no enable needed.
systemctl enable firewalld
systemctl enable fail2ban
systemctl enable aryaos-gps-time-sync.service
systemctl enable aryaos-tak-dp-importd.service
systemctl enable aryaos-neighbord.service
# EMCON: re-applies WiFi/Bluetooth rfkill at boot when /etc/aryaos/emcon is set.
systemctl enable aryaos-radio-silence.service

getent group gpsd >/dev/null || groupadd --system gpsd
systemctl enable gpsd
usermod -aG gpsd www-data || true
usermod -aG gpsd lincot || true
usermod -aG ssl-cert www-data || true
usermod -aG video www-data || true
usermod -aG video lincot || true
