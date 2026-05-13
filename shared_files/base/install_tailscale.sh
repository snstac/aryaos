#!/bin/bash
# install_tailscale.sh
#
# Installs Tailscale via https://tailscale.com/install.sh (adds apt repo, installs packages).
# Does not run `tailscale up`; enroll on the device with `sudo tailscale up`.
#
# SPDX-License-Identifier: Apache-2.0
# Copyright Sensors & Signals LLC https://www.snstac.com/

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if command -v tailscale >/dev/null 2>&1 && [ -x /usr/sbin/tailscaled ]; then
	echo "*** Tailscale already installed."
	exit 0
fi

curl -fsSL https://tailscale.com/install.sh | sh

if command -v systemctl >/dev/null 2>&1; then
	systemctl enable tailscaled.service || true
fi
