#!/bin/bash -e
# 00-run.sh
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

# pi-gen often does not export SHARED_FILES into NN-run.sh; without it,
# "${SHARED_FILES}/dronecot/..." becomes "/dronecot/...".
if [[ -z "${SHARED_FILES:-}" || ! -d "${SHARED_FILES}" ]]; then
	if [[ -d "/aryaos/shared_files" ]]; then
		SHARED_FILES="/aryaos/shared_files"
	else
		SHARED_FILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/shared_files"
	fi
fi
export SHARED_FILES

rsync -va "${SHARED_FILES}/dronecot/docker-uas-broker" "${ROOTFS_DIR}/usr/src/"
rsync -va "${SHARED_FILES}/dronecot/docker-uas-sensor" "${ROOTFS_DIR}/usr/src/"

install -v -m 755 "${SHARED_FILES}/dronecot/aryaos-dronecot-ready" "${ROOTFS_DIR}/usr/local/sbin/"
# AryaOS names the DJI/AntSDR instance explicitly. The generic upstream unit is
# masked in the chroot step so "dronecot" cannot silently mean DJI.
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/dronecot-dji.service" \
	"${ROOTFS_DIR}/etc/systemd/system/dronecot-dji.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/dronecot-dji.default" \
	"${ROOTFS_DIR}/etc/default/dronecot-dji"

# DroneScout DS101/DS110: a SECOND dronecot instance reading MAVLink Remote ID
# from a protocol-verified USB serial path. The ExecCondition helper keeps a
# missing/unplugged receiver inactive rather than letting it restart-loop.
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/dronecot-dronescout.service" \
	"${ROOTFS_DIR}/etc/systemd/system/dronecot-dronescout.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/dronecot-dronescout.default" \
	"${ROOTFS_DIR}/etc/default/dronecot-dronescout"
install -d -m 0755 "${ROOTFS_DIR}/usr/local/libexec/aryaos"
install -v -m 0755 "${SHARED_FILES}/aryaos/dronecot-serial-ready" \
	"${ROOTFS_DIR}/usr/local/libexec/aryaos/dronecot-serial-ready"

# Wi-Fi Remote ID: an opt-in dronecot instance that decodes Open Drone ID from
# 802.11 (ASTM Beacon + Wi-Fi Alliance NAN) via a monitor-mode adapter (ath9k_htc
# / Realtek 8821CU). Needs python3-scapy (installed via 00-packages). Off by
# default — enable on a box with an external monitor-capable Wi-Fi adapter.
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/dronecot-wifi.service" \
	"${ROOTFS_DIR}/etc/systemd/system/dronecot-wifi.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/dronecot-wifi.default" \
	"${ROOTFS_DIR}/etc/default/dronecot-wifi"
# Bluetooth Remote ID: an opt-in dronecot instance that decodes Open Drone ID
# from BLE advertisements using the board's OWN Bluetooth radio — the only
# sensor needing no add-on hardware, which is precisely why it must stay opt-in
# (auto-enabling would switch a sensor on across the entire fleet).
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/dronecot-ble.service" \
	"${ROOTFS_DIR}/etc/systemd/system/dronecot-ble.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/dronecot-ble.default" \
	"${ROOTFS_DIR}/etc/default/dronecot-ble"

# Monitor-mode prep helper (dronecot's own set_monitor_mode doesn't down the
# iface first nor release it from NetworkManager) — used as ExecStartPre.
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-wifi-monitor" \
	"${ROOTFS_DIR}/usr/local/sbin/aryaos-wifi-monitor"
# Pin a stable /dev/dronescout symlink for the DS101's ESP32-S3 USB-serial (its
# by-id path embeds the per-unit MAC, so it can't be hard-coded). The DS101 is
# the ESP32-S3 CDC port (303a:1001), NOT a CH340 — verified live 2026-07-24.
install -v -m 0644 "${SHARED_FILES}/aryaos/udev/99-aryaos-dronescout.rules" \
	"${ROOTFS_DIR}/etc/udev/rules.d/99-aryaos-dronescout.rules"

# AntSDR E200 management: the AntSDR pushes DJI DroneID over Ethernet (:52002 ->
# dronecot); its CH340 USB-serial is the Zynq config/recovery console (root/analog).
#  - aryaos-antsdr-console: `tio` wrapper to reach that console from the Pi.
#  - aryaos-antsdr-health:  observe the DroneID feed (reachable + socket ESTAB),
#    write /run/aryaos/antsdr-health.json for Cockpit + syslog. Timer-driven.
#  - 99-aryaos-antsdr-console.rules: opt-in /dev/antsdr-console symlink (gated on
#    /etc/aryaos/antsdr-console.enabled since 1a86:7523 is a generic CH340).
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-antsdr-console" \
	"${ROOTFS_DIR}/usr/local/sbin/aryaos-antsdr-console"
install -v -m 0755 "${SHARED_FILES}/aryaos/aryaos-antsdr-health" \
	"${ROOTFS_DIR}/usr/local/sbin/aryaos-antsdr-health"
install -v -m 0644 "${SHARED_FILES}/aryaos/udev/99-aryaos-antsdr-console.rules" \
	"${ROOTFS_DIR}/etc/udev/rules.d/99-aryaos-antsdr-console.rules"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-antsdr-health.service" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-antsdr-health.service"
install -v -m 0644 "${SHARED_FILES}/aryaos/systemd/aryaos-antsdr-health.timer" \
	"${ROOTFS_DIR}/etc/systemd/system/aryaos-antsdr-health.timer"
