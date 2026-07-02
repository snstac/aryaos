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
