#!/bin/bash -e
# Ship every sensor gateway DISABLED.
#
# The sensor debs enable themselves in their postinst, so a stock image booted
# with no radios attached spends its life crash-looping: readsb/dump978-fa/
# adsbcot restart dozens of times before systemd gives up, aiscot and
# sikw00fcot sit "active" against hardware that isn't there, and the journal
# fills with failures that look like a broken appliance.
#
# Instead, capability drives everything: nothing sensor-related runs until
# `aryaos-role product <line>` / `aryaos-role caps <cap...>` turns it on. The
# CoT core (charontak, lincot, gpsd) is untouched and always runs, so a box with
# no capabilities is still a working TAK node that beacons its own position.
#
# This runs in the LAST stage on purpose — stage-bt-pan carries EXPORT_IMAGE —
# so it lands after every sensor package (and its postinst) is installed.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0

SENSOR_UNITS="
readsb
dump1090-fa
dump978-fa
adsbcot
gdltak
ais-catcher
aiscot
dronecot
dronecot-wifi
dronecot-ble
dronecot-dronescout
sikw00fcot
sapientcot
acarsdec
acarscot
"

for unit in ${SENSOR_UNITS}; do
	if systemctl list-unit-files --no-legend "${unit}.service" 2>/dev/null | grep -q .; then
		systemctl disable "${unit}.service" >/dev/null 2>&1 || true
		echo "sensors-off: disabled ${unit}.service"
	fi
done

# Make the empty capability set explicit rather than implied by a missing
# variable, so `aryaos-role list` and the beacon report something meaningful on a
# fresh image.
#
# ARYAOS_PRODUCT is deliberately NOT written here any more. Writing a product line
# at build time meant every box in the fleet advertised the same one -- most of
# them "DragonEgg" -- no matter what hardware was attached, which is how a box
# with an AntSDR and a DroneScout ended up claiming to be a DragonEgg. A field
# that is always the same carries no information but looks authoritative, so it
# was removed rather than guessed at. Capabilities are measured instead.
#
# Boxes flashed from an older image keep an inert ARYAOS_PRODUCT line in their
# config until they are re-flashed; nothing reads it.
CONFIG="/etc/aryaos/aryaos-config.txt"
if [[ -f "${CONFIG}" ]]; then
	grep -qE '^#?\s*ARYAOS_CAPABILITIES=' "${CONFIG}" || printf 'ARYAOS_CAPABILITIES=""\n' >>"${CONFIG}"
fi

echo "sensors-off: image ships with no sensor capabilities enabled"
