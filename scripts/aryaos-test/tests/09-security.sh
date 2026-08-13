#!/usr/bin/env bash
# 09-security.sh — hardening + one-click-update posture (remote on Pi).
#
# Everything here degrades to warn on images built before the hardening
# landed, so the suite stays useful against older lab burns.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"

# --- firewalld ---
if command -v firewall-cmd >/dev/null 2>&1; then
	if [[ "$(sudo -n firewall-cmd --state 2>/dev/null)" == "running" ]]; then
		ok "firewalld running"
		zone_services="$(sudo -n firewall-cmd --list-services 2>/dev/null || true)"
		for svc in ssh https aryaos-mesh-sa; do
			if grep -qw "${svc}" <<<"${zone_services}"; then
				ok "firewall allows ${svc}"
			else
				fail "firewall missing ${svc} in default zone (got: ${zone_services})"
			fi
		done
	else
		fail "firewalld installed but not running"
	fi
	if dpkg-query -W -f='${Status}' gutcheck 2>/dev/null | grep -q "install ok installed"; then
		if sudo -n firewall-cmd --zone=public --query-service=aryaos-gutcheck >/dev/null 2>&1; then
			ok "Gutcheck dashboard reachable on the trusted LAN"
		else
			fail "Gutcheck installed but blocked on the trusted LAN"
		fi
		if sudo -n firewall-cmd --zone=aryaos-hotspot --query-service=aryaos-gutcheck >/dev/null 2>&1; then
			fail "Gutcheck exposed to the onboarding hotspot"
		else
			ok "Gutcheck withheld from the onboarding hotspot"
		fi
	fi
else
	warn "firewalld not installed (pre-hardening image?)"
fi

# --- fail2ban ---
if command -v fail2ban-client >/dev/null 2>&1; then
	if sudo -n fail2ban-client status sshd >/dev/null 2>&1; then
		ok "fail2ban sshd jail active"
	else
		fail "fail2ban installed but sshd jail not active"
	fi
else
	warn "fail2ban not installed (pre-hardening image?)"
fi

# --- sshd effective config ---
if sudo -n sshd -T 2>/dev/null | grep -qi '^permitrootlogin no$'; then
	ok "sshd: PermitRootLogin no (effective)"
else
	warn "sshd: root login not disabled (pre-hardening image?)"
fi
if sudo -n sshd -T 2>/dev/null | grep -qi '^passwordauthentication yes$'; then
	ok "sshd: password auth stays enabled (field access contract)"
else
	fail "sshd: password auth disabled — field units would be locked out"
fi

# --- sysctl ---
if [[ "$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null)" == "0" ]]; then
	ok "sysctl: ICMP redirects not accepted"
else
	warn "sysctl hardening not applied (pre-hardening image?)"
fi

# --- unattended security upgrades ---
if [[ -f /etc/apt/apt.conf.d/52unattended-upgrades-aryaos ]]; then
	ok "unattended-upgrades AryaOS policy present"

	# A policy file and a working dry-run prove unattended-upgrades COULD run.
	# Neither proves anything ever STARTS it. On aryaos-c998 both of those
	# passed while apt-daily-upgrade.timer was disabled, so no Debian security
	# fix would ever have been applied -- the check reported a security posture
	# the box did not have.
	if systemctl is-enabled apt-daily-upgrade.timer >/dev/null 2>&1; then
		ok "apt-daily-upgrade.timer enabled (something actually triggers upgrades)"
	else
		fail "apt-daily-upgrade.timer disabled — unattended-upgrades will never run"
	fi
	if systemctl is-enabled apt-daily.timer >/dev/null 2>&1; then
		ok "apt-daily.timer enabled (package lists get refreshed)"
	else
		fail "apt-daily.timer disabled — package lists never refresh, so upgrades find nothing"
	fi

	if sudo -n unattended-upgrade --dry-run --debug >/dev/null 2>&1; then
		ok "unattended-upgrade dry-run succeeds"
	else
		warn "unattended-upgrade dry-run failed (offline or apt lock?)"
	fi
else
	warn "unattended-upgrades policy missing (pre-hardening image?)"
fi

# --- one-click update path ---
if [[ -x /usr/local/sbin/aryaos-update ]]; then
	ok "aryaos-update helper present"
	if sudo -n /usr/local/sbin/aryaos-update status | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
		ok "aryaos-update status emits valid JSON"
	else
		fail "aryaos-update status output is not valid JSON"
	fi
	if systemctl cat aryaos-update.service >/dev/null 2>&1; then
		ok "aryaos-update.service unit present"
	else
		fail "aryaos-update.service unit missing"
	fi
else
	warn "aryaos-update not installed (pre-hardening image?)"
fi

if dpkg-query -W -f='${Status}' cockpit-packagekit 2>/dev/null | grep -q "install ok installed"; then
	ok "cockpit-packagekit installed (Cockpit Software Updates page)"
else
	warn "cockpit-packagekit not installed"
fi

# GHSA-2m8v-j782-fhvr permits a zero-attachment Socket.IO packet to exhaust
# memory before socket.io-parser 4.2.7. This is runtime code in the Node-RED
# editor, so verify the installed module rather than only the image lockfile.
SOCKET_IO_PARSER_PACKAGE=/home/node-red/.node-red/node_modules/socket.io-parser/package.json
SOCKET_IO_PARSER_VERSION="$(node -p "require('${SOCKET_IO_PARSER_PACKAGE}').version" 2>/dev/null || true)"
if [[ -n "${SOCKET_IO_PARSER_VERSION}" ]] && dpkg --compare-versions "${SOCKET_IO_PARSER_VERSION}" ge 4.2.7; then
	ok "Node-RED Socket.IO parser ${SOCKET_IO_PARSER_VERSION} has memory-exhaustion fix"
else
	fail "Node-RED Socket.IO parser ${SOCKET_IO_PARSER_VERSION:-missing}, expected >= 4.2.7"
fi

# --- flash-media longevity ---
if swapon --noheadings --show=NAME 2>/dev/null | grep -qx '/dev/zram0'; then
	ok "RAM-only zram swap active"
else
	fail "zram swap is not active"
fi
if [[ -r /sys/block/zram0/backing_dev ]]; then
	zram_backing="$(< /sys/block/zram0/backing_dev)"
	if [[ "${zram_backing}" == "none" ]]; then
		ok "zram has no install-media writeback device"
	else
		fail "zram writes back to ${zram_backing} (want RAM-only)"
	fi
fi
if [[ -e /var/swap ]]; then
	fail "/var/swap exists despite the RAM-only swap policy"
else
	ok "no install-media swapfile"
fi
if dpkg-query -W -f='${Status}' rpi-swap 2>/dev/null | grep -q "install ok installed"; then
	if grep -qs '^Mechanism=zram$' /etc/rpi/swap.conf.d/90-aryaos.conf; then
		ok "rpi-swap explicitly pinned to file-free zram"
	else
		fail "rpi-swap can fall back to disk-backed zram+file"
	fi
fi
if sudo -n grep -qs '^Defaults maxseq=128$' /etc/sudoers.d/aryaos; then
	ok "sudo I/O audit history bounded for RAM-backed /var/log"
else
	fail "sudo I/O logs are unbounded and can fill RAM-backed /var/log"
fi
log_used_pct="$(df --output=pcent /var/log 2>/dev/null | tail -n 1 | tr -dc '0-9')"
if [[ "${log_used_pct}" =~ ^[0-9]+$ && "${log_used_pct}" -lt 95 ]]; then
	ok "/var/log has headroom (${log_used_pct}% used)"
else
	fail "/var/log is full or unavailable (${log_used_pct:-unknown}% used)"
fi
for tmp_mount in /tmp /var/tmp; do
	tmp_used_pct="$(df --output=pcent "${tmp_mount}" 2>/dev/null | tail -n 1 | tr -dc '0-9')"
	if [[ "${tmp_used_pct}" =~ ^[0-9]+$ && "${tmp_used_pct}" -lt 95 ]]; then
		ok "${tmp_mount} has headroom (${tmp_used_pct}% used)"
	else
		fail "${tmp_mount} is full or unavailable (${tmp_used_pct:-unknown}% used)"
	fi
done

# --- TLS key hygiene ---
if [[ -f /etc/aryaos/.web-tls-regenerated ]]; then
	ok "per-device web TLS cert regenerated at first boot"
else
	warn "web TLS still the image-wide snakeoil key (pre-hardening image?)"
fi
if [[ -d /etc/aryaos/tls ]]; then
	tls_owner="$(stat -c '%U' /etc/aryaos/tls)"
	if [[ "${tls_owner}" == "root" ]]; then
		ok "/etc/aryaos/tls owned by root"
	else
		fail "/etc/aryaos/tls owned by ${tls_owner} (TAK key exposure)"
	fi
	if [[ -f /etc/aryaos/tls/client.key ]]; then
		key_mode="$(stat -c '%a' /etc/aryaos/tls/client.key)"
		if [[ "${key_mode}" == "640" ]]; then
			ok "TAK client key mode 0640"
		else
			fail "TAK client key mode ${key_mode} (want 0640)"
		fi
	fi
else
	skip "no site TAK TLS installed"
fi

print_summary
