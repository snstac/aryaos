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


# Set SDR Serial for dump1090 & dump978
DUMP1090_RECEIVER_SERIAL="stx:1090:0"
sed --follow-symlinks -i -E -e "s/RECEIVER_SERIAL.*/RECEIVER_SERIAL=$DUMP1090_RECEIVER_SERIAL/" /etc/default/dump1090-fa
DUMP978_RECEIVER_SERIAL="stx:978:0"
sed --follow-symlinks -i -E -e "s/driver=rtlsdr /driver=rtlsdr,serial=$DUMP978_RECEIVER_SERIAL /" /etc/default/dump978-fa

# readsb: stock .deb lacks RTL-SDR; rebuild binary then restore AryaOS systemd unit.
dpkg -i /usr/src/readsb_3.14.1621_arm64.deb
bash /usr/src/readsb-install.sh no-tar1090
touch /usr/local/share/adsb-wiki/readsb-install/aryaos-readsb-built
install -v -m 644 /usr/src/readsb.service.aryaos /lib/systemd/system/readsb.service

READSB_RECEIVER_SERIAL="stx:1090:0"
sed --follow-symlinks -i -E -e "s/RECEIVER_OPTIONS.*/RECEIVER_OPTIONS=\"--device-type rtlsdr --device $READSB_RECEIVER_SERIAL --gain -10 --ppm 0\"/" /etc/default/readsb

# tar1090
bash /usr/src/tar1090-install.sh

# adsbcot FEED_URL + mutual exclusivity for 1090 MHz decoder.
# Default readsb; export ARYAOS_ADSB_DECODER_DEFAULT=dump1090_fa during pi-gen to match vars.yml aryaos_adsb_decoder.
ARYAOS_ADSB_DECODER_DEFAULT="${ARYAOS_ADSB_DECODER_DEFAULT:-readsb}"
if [[ "${ARYAOS_ADSB_DECODER_DEFAULT}" == "dump1090_fa" ]]; then
	sed --follow-symlinks -i -E -e "s/FEED_URL.*/FEED_URL=file:\/\/\/run\/adsb\/aircraft.json/" /etc/default/adsbcot
else
	sed --follow-symlinks -i -E -e "s/FEED_URL.*/FEED_URL=file:\/\/\/run\/readsb\/aircraft.json/" /etc/default/adsbcot
fi

# Remove # from the line containing FEED_URL in /etc/default/adsbcot
sed --follow-symlinks -i -E -e "s/^# (FEED_URL.*)/\1/" /etc/default/adsbcot

# Add the line EnvironmentFile=/etc/aryaos/aryaos-config.txt to /lib/systemd/system/adsbcot.service if the line does not already exist
grep -qxF "EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/adsbcot.service || sed --follow-symlinks -i -E -e "/\[Service\]/a EnvironmentFile=/etc/aryaos/aryaos-config.txt" /lib/systemd/system/adsbcot.service

systemctl daemon-reload || true
if [[ "${ARYAOS_ADSB_DECODER_DEFAULT}" == "dump1090_fa" ]]; then
	systemctl disable --now readsb.service 2>/dev/null || true
	systemctl enable dump1090-fa.service 2>/dev/null || true
else
	systemctl disable --now dump1090-fa.service 2>/dev/null || true
	systemctl enable readsb.service 2>/dev/null || true
fi

# Cockpit module for adsbcot (Polkit rules + /usr/share/cockpit/adsbcot). Deb version must match vars.yml.
dpkg -i /usr/src/cockpit-adsbcot_1.0.8_all.deb
