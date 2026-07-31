#!/bin/bash -e
# AryaOS 00-run-chroot.sh
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

apt update

systemctl disable dphys-swapfile.service
systemctl disable man-db.timer

# The apt timers are deliberately NOT disabled here any more.
#
# This stage runs AFTER stage-aryaos (see STAGE_LIST in config), and
# stage-aryaos installs the unattended-upgrades policy on the explicit
# assumption that they exist:
#
#   stage-aryaos/00-install/01-run-chroot.sh:
#     "unattended-upgrades runs via the static apt-daily timers; no enable
#      needed."
#
# Disabling them here silently undid that. Measured on aryaos-c998:
#
#   apt-daily.timer          active=inactive  enabled=disabled
#   apt-daily-upgrade.timer  active=inactive  enabled=disabled
#
# and unattended-upgrades had only ever run its SHUTDOWN unit -- never an
# actual upgrade. The box was never going to apply a Debian security fix,
# while the code comments and the security test both said it would.
#
# Disabling man-db indexing and dphys-swapfile is about media longevity and
# is kept. Disabling security updates is a different kind of decision and
# was not an intentional one.

# Media longevity: dphys-swapfile is off (no swapfile writes to the SD/NVMe).
# Provide zram compressed RAM swap so memory spikes do not OOM-kill services,
# and enable periodic TRIM. The zram config ships from the aryaos-overlay
# (/etc/systemd/zram-generator.conf).
apt-get install -y --no-install-recommends systemd-zram-generator || true
systemctl enable fstrim.timer || true

if [[ -f /etc/cron.hourly/fake-hwclock ]]; then
	mv /etc/cron.hourly/fake-hwclock /etc/cron.daily/
fi

if [[ -d /etc/cron.daily ]]; then
	pushd /etc/cron.daily > /dev/null
	rm -f apt-compat bsdmainutils dpkg man-db
	popd > /dev/null
fi

if ! grep -qs -e '/tmp' /etc/fstab; then
     sed -i -E -e 's/(vfat *defaults) /\1,noatime/g' /etc/fstab
cat >> /etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/log tmpfs defaults,noatime,nosuid,size=50M	0	0
tmpfs /var/lib/systemd/timers tmpfs defaults,noatime,nosuid,size=50M 	0	0
EOF
fi

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
