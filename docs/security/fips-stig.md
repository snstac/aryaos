# FIPS & STIG roadmap

This is a **roadmap**, not a compliance claim. AryaOS is not currently STIG-
certified or FIPS-validated. This page maps the [existing security
posture](../security.md) onto the two compliance regimes, states honestly what
is and isn't achievable on the Debian base, and lays out a phased path for
programs that need a formal posture (RMF / ATO).

Two different things are often conflated:

- **STIG** (DISA Security Technical Implementation Guide) — a **configuration
  hardening baseline**. Achievable incrementally on the current image.
- **FIPS 140-3** — use of **NIST-validated cryptographic modules**. Constrained
  by the Debian base and largely a business/re-base decision.

---

## Where AryaOS already aligns

The shipped hardening already satisfies a meaningful slice of the STIG control
families (all in both dev and release images):

| STIG family | AryaOS control | Where |
|---|---|---|
| AC (Access Control) | root SSH off, `MaxAuthTries 4`, sudo logged, no NOPASSWD on release | `sshd/50-aryaos.conf`, `aryaos.sudoers` |
| IA (Identification & Auth) | default password force-expired first boot; per-device SSH + web TLS keys | `aryaos-firstboot.sh` |
| SC (System & Comms) | firewalld allowlist, loopback-only cockpit-ws + TLS termination, sysctl network hardening | `firewalld/`, `sysctl/90-aryaos-hardening.conf` |
| SI (System Integrity) | automatic Debian security updates; signed apt repo | `apt/52unattended-upgrades-aryaos` |
| CM (Configuration Mgmt) | image content asserted every build; reproducible pi-gen | `scripts/verify-image.sh` |
| MP (Media Protection) | factory-reset + zeroize (shred/TRIM/overwrite) | `aryaos-zeroize` |
| AU (Audit) | sudo I/O logging, capped journald | partial — see gaps |

## Known gaps vs a STIG baseline

Likely findings on a first scan, and the AryaOS disposition:

- **AU (audit)**: no `auditd` / audit rules shipped. *Fix* (Phase 1).
- **SI (file integrity)**: no AIDE baseline. *Fix* (Phase 1).
- **IA (password quality)**: no `pam_pwquality` / lockout policy beyond fail2ban. *Fix* (Phase 1).
- **CM (mount options)**: `/tmp`, `/var/tmp`, `/dev/shm` lack `nodev,nosuid,noexec`; unused kernel modules (cramfs, usb-storage, etc.) not blacklisted. *Fix* (Phase 1).
- **AC (session)**: no shell idle timeout (`TMOUT`); no login-attempt lockout via `pam_faillock`. *Fix* (Phase 1).
- **Waivered by the appliance model** (documented exceptions, not silent):
  - **Password SSH auth stays enabled** — field operators may carry no keys; mitigated by first-boot expiry + `fail2ban` + `MaxAuthTries`. (SRG-OS SSH-key-only requirement.)
  - **comitup AP / Bluetooth PAN onboarding** — attack surface, mitigated by EMCON (`aryaos-radio`) + firewall zone isolation.
  - **No FDE by default** — zeroize is best-effort on flash; FDE + crypto-erase is on the roadmap.
  - **Headless** — GUI/screen-lock STIGs are N/A.

---

## STIG track (achievable, incremental)

There is **no official DISA STIG for Debian**. The practical baselines are the
**CIS Debian 12 Benchmark** and the **General Purpose OS SRG**, both shipped as
OpenSCAP content in the **SCAP Security Guide** (`ssg-debian`). (If a program
mandates a real DISA STIG, the closest validated path is a **Canonical Ubuntu
STIG** — see the re-base note under FIPS.)

**Phase 1 — measure (non-invasive, do first).**
Add an OpenSCAP scan to the test harness so every image gets a baseline score:

```bash
# new: scripts/aryaos-test/tests/10-compliance.sh (runs on a live unit)
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results-arf /var/lib/aryaos/compliance/arf.xml \
  --report /var/lib/aryaos/compliance/report.html \
  /usr/share/xml/scap/ssg/content/ssg-debian12-ds.xml
```

Triage findings into: already-met · will-fix · **waivered-with-rationale**
(captured in an OpenSCAP **tailoring file**, `aryaos-stig-tailoring.xml`, so the
appliance exceptions above are explicit and re-scored automatically).

**Phase 2 — remediate.** Land the Phase-1 gap fixes (auditd, AIDE,
pam_pwquality/faillock, mount options, module blacklist, `TMOUT`) as
hardening drop-ins, each asserted by `verify-image.sh`. Target a documented CIS
score and publish the report + tailoring with each release.

**Phase 3 — surface.** A Cockpit → *Compliance* card showing the last scan
score, top open findings, and the waiver list — so an operator/assessor sees
posture without a shell.

---

## FIPS track (constrained, longer-term)

**The honest reality:** Debian's OpenSSL/libgcrypt are **not NIST-validated**.
Booting with `fips=1` does **not** confer compliance without validated modules.
FIPS 140-3 is therefore a **module-sourcing** problem, and largely a re-base /
procurement decision — not a config change.

**Options, roughly in order of effort:**

1. **FIPS-approved algorithm enforcement ("FIPS-configured", near-term).** Even
   without a validated module, restrict every crypto path to FIPS-approved
   primitives and document the inventory. This is immediately shippable and is
   usually a prerequisite line-item anyway:
   - **sshd**: pin `Ciphers`/`MACs`/`KexAlgorithms` to the FIPS set
     (`aes256-gcm`, `hmac-sha2-512`, `ecdh-sha2-nistp384`, …) in
     `sshd/50-aryaos.conf`.
   - **lighttpd/cockpit TLS**: TLS 1.2+ only, FIPS cipher suites (AES-GCM,
     SHA-2, ECDHE-RSA/ECDSA).
   - **pytak → TAK Server TLS**, **chrony**, **charontak**: confirm AES-GCM /
     SHA-2 / RSA-2048+ or P-256/384 throughout.
   - Deliverable: a **crypto inventory** table (component → library → algorithms
     → key sizes) maintained in this repo.
2. **OpenSSL 3 FIPS provider.** Build and activate the OpenSSL FIPS provider
   module. Gets the *architecture* right; a genuine certificate still requires a
   validated build.
3. **Validated modules via re-base.** **Ubuntu Pro FIPS** ships NIST-validated
   OpenSSL, kernel crypto, libgcrypt, and StrongSwan for `arm64`. This is the
   realistic path to an actual 140-3 posture, at the cost of re-basing AryaOS
   (or a FIPS build variant) off Ubuntu and an Ubuntu Pro subscription.
4. **Targeted commercial module (wolfSSL FIPS).** For a narrow validated crypto
   boundary (e.g. the TAK TLS path) without a full re-base.

**Recommendation:** do (1) now — it is real hardening with no re-base — and hold
(3) behind an actual ATO requirement, since re-basing the whole image is a large
program decision.

---

## First step

Land **Phase-1 measurement**: the `oscap` scan in the test harness + a starter
tailoring file, and the sshd/TLS FIPS-cipher pinning from FIPS option (1). Both
are non-destructive, immediately useful, and turn "we should think about
FIPS/STIG" into a scored baseline we can drive down release over release.

See also: [Security posture](../security.md) · [Zeroize](../operations/zeroize.md).
