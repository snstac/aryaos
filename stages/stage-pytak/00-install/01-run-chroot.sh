#!/bin/bash -e
# AryaOS 01-run-chroot.sh - Install PyTAK and related packages from shared manifest.
#
# Copyright Sensors & Signals LLC https://www.snstac.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/usr/src/install-sensor-debs.sh /usr/src/aryaos-sensor-packages.yml

# Register the AryaOS appliance overlay package (built by stage-aryaos into
# /usr/src). Installed here, not in stage-aryaos: it Depends on pytak, which
# is only resolvable once install-sensor-debs.sh has configured the snstac
# apt repo above. No dpkg -i fallback — an unresolvable dependency must fail
# the build, not leave the package unconfigured.
if [[ -f /usr/src/aryaos-overlay.deb ]]; then
	DEBIAN_FRONTEND=noninteractive apt-get install -y /usr/src/aryaos-overlay.deb
fi

/usr/src/patch-cockpit-aryaos-dp
