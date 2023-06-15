#!/bin/bash -e
#
# Copyright 2023 Sensors & Signals LLC
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
apt dist-upgrade -y

systemctl disable dphys-swapfile.service
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable man-db.timer

mv /etc/cron.hourly/fake-hwclock /etc/cron.daily || true

pushd /etc/cron.daily
rm -f apt-compat bsdmainutils dpkg man-db
popd

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

# echo -n "${FIRST_USER_NAME:='pi'}:" > /boot/userconf.txt
# openssl passwd -5 "${FIRST_USER_PASS:='raspberry'}" >> /boot/userconf.txt
