#!/bin/bash -e
# AryaOS 01-run-chroot.sh - Install PyTAK and related packages from shared manifest.
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/usr/src/install-sensor-debs.sh /usr/src/aryaos-sensor-packages.yml
/usr/src/patch-cockpit-aryaos-dp
