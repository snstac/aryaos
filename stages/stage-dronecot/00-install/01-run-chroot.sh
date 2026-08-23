#!/bin/bash -e
# 01-run-chroot.sh — enable the AntSDR DroneID feed health timer (observability
# only; the check writes /run/aryaos/antsdr-health.json + syslog and never
# restarts anything). Harmless on boxes without an AntSDR — the check simply
# reports "down" and the timer costs a socket query every 30s.
#
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0

systemctl daemon-reload 2>/dev/null || true
systemctl disable dronecot.service 2>/dev/null || true
systemctl mask dronecot.service 2>/dev/null || true
systemctl enable aryaos-antsdr-health.timer 2>/dev/null || true
