#!/bin/bash
# run_readsb.sh Startup file for readsb.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at 
# 
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -a

AOS_CONFIG="/etc/aryaos/aryaos-config.txt"

if [ -f $AOS_CONFIG ]; then
  # shellcheck source=aryaos-config.txt
  . $AOS_CONFIG
fi

READSB_CONFIG="/etc/default/readsb"

if [ -f "${READSB_CONFIG}" ]; then
  # shellcheck source=readsb-config.txt
  . "${READSB_CONFIG}"
fi

# Written by aryaos-adsbee (ordered Before=readsb.service): says whether a
# hardware ADSBee receiver was found, and on which by-id path.
ADSBEE_ENV="/run/aryaos/adsbee.env"

if [ -f "${ADSBEE_ENV}" ]; then
  # shellcheck source=/dev/null
  . "${ADSBEE_ENV}"
fi

set +a

: "${ADSB_JSON:=${ARYAOS_ADSB_JSON_DIR:-/run/adsb}}"

# Receiver selection. "auto" (the default) prefers a hardware ADSBee when one is
# present, and otherwise leaves the SDR RECEIVER_OPTIONS from /etc/default/readsb
# untouched -- so SDR boxes are unaffected. Pin to rtlsdr/soapysdr to keep using
# an SDR even with an ADSBee attached.
use_adsbee=0
case "${ARYAOS_ADSB_RECEIVER:-auto}" in
  adsbee) use_adsbee=1 ;;
  auto)   [ "${ARYAOS_ADSBEE_PRESENT:-0}" = "1" ] && use_adsbee=1 ;;
esac

if [ "${use_adsbee}" = "1" ] && [ -n "${ARYAOS_ADSBEE_DEVICE:-}" ]; then
  # The ADSBee demodulates 1090 Mode S and 978 UAT in hardware and emits both as
  # Mode S Beast (UAT encapsulated in frame type 0xec, which readsb converts via
  # uat2esnt). readsb reads that straight off the serial port -- no SDR, no socat
  # shim, and effectively no CPU, because nothing here demodulates.
  RECEIVER_OPTIONS="--device-type modesbeast --beast-serial ${ARYAOS_ADSBEE_DEVICE}"
fi

# RECEIVER_OPTIONS etc. are multiple CLI flags; they must be word-split (not one argv).
# shellcheck disable=SC2086
exec /usr/bin/readsb \
	${RECEIVER_OPTIONS} ${DECODER_OPTIONS} ${NET_OPTIONS} ${JSON_OPTIONS} \
	--write-json "${ADSB_JSON}" --quiet