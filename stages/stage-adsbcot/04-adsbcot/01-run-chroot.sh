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

# readsb: Debian trixie apt package lacks RTL/Soapy; rebuild with portable arm64 flags + SDR backends.
dpkg -i /usr/src/readsb_3.14.1621_arm64.deb
bash /usr/src/readsb-install.sh no-tar1090
touch /usr/local/share/adsb-wiki/readsb-install/aryaos-readsb-built
READSB_HELP="$(/usr/bin/readsb --help 2>&1)"
echo "${READSB_HELP}" | grep -qE 'RTL-SDR|rtlsdr' || { echo "readsb missing RTL-SDR support" >&2; exit 1; }
echo "${READSB_HELP}" | grep -qiE 'SoapySDR|soapysdr' || { echo "readsb missing SoapySDR support" >&2; exit 1; }
echo "${READSB_HELP}" | grep -qiE 'HackRF|hackrf' || { echo "readsb missing HackRF support" >&2; exit 1; }
/usr/bin/readsb --version >/dev/null 2>&1 || { echo "readsb binary failed to execute" >&2; exit 1; }
install -v -m 644 /usr/src/readsb.service.aryaos /lib/systemd/system/readsb.service
# Prevent apt from replacing the SDR-enabled binary with stock trixie readsb (3.14.1630+; no RTL).
apt-mark hold readsb || true

READSB_RECEIVER_SERIAL="stx:1090:0"
sed --follow-symlinks -i -E -e "s/RECEIVER_OPTIONS.*/RECEIVER_OPTIONS=\"--device-type rtlsdr --device $READSB_RECEIVER_SERIAL --gain -10 --ppm 0\"/" /etc/default/readsb
grep -q '^ADSB_JSON=' /etc/default/readsb 2>/dev/null && \
	sed --follow-symlinks -i -E -e 's|^ADSB_JSON=.*|ADSB_JSON=/run/adsb|' /etc/default/readsb || \
	echo 'ADSB_JSON=/run/adsb' >> /etc/default/readsb

# tar1090
bash /usr/src/tar1090-install.sh

# adsbcot FEED_URL — same path for readsb and dump1090-fa (/run/adsb/aircraft.json).
sed --follow-symlinks -i -E -e "s/FEED_URL.*/FEED_URL=file:\/\/\/run\/adsb\/aircraft.json/" /etc/default/adsbcot

# 1090 MHz decoder enablement (mutually exclusive). Default readsb; export ARYAOS_ADSB_DECODER_DEFAULT=dump1090_fa to match vars.yml.
ARYAOS_ADSB_DECODER_DEFAULT="${ARYAOS_ADSB_DECODER_DEFAULT:-readsb}"

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

# Cockpit module for adsbcot (Polkit rules + /usr/share/cockpit/adsbcot),
# from the snstac apt repo (configured by stage-pytak).
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cockpit-adsbcot
