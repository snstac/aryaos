# AOS2 launch claims ledger (internal)

This file is excluded from the published documentation. It is the editorial
source of truth for public AOS2 claims. Recheck volatile release links and test
counts immediately before publication.

| Public claim | Evidence | Approved wording / limit |
|---|---|---|
| AOS2 is a complete rewrite | `CHANGELOG.md`; rewrite commits `4590c95`, `dc503ff`; current shared stages | “Complete rewrite,” not a line-by-line rewrite percentage |
| v1 baseline is April 2024 | Commit `6a9ac2b` and merge `a0c7b08`; v1 tree and changelog | Compare to public AryaOS 1.0, not every later checkpoint |
| Debian Trixie arm64 | `config`, `config.docker`, `docs/specs.md` | Image supports Pi 3/4/5 arm64; amd64 image remains planned |
| 55-mile offline ADS-B result | `docs/get-started/hardware.md` “Range in the field” | One San Diego backpack test; never state guaranteed range |
| No cloud or subscription required | `README.md`; `docs/deploy/offline-backpack.md` | Applies to local sensing/admin/Mesh SA, not remote server, VPN, updates, or online feeds |
| Routine use needs no terminal | Cockpit and portal docs; `docs/admin/`; helper-backed cards | Say “routine” or enumerate browser tasks; advanced SDR/query tools remain CLI |
| Sensors are quiet by default | `stages/stage-bt-pan/01-sensors-off/00-run-chroot.sh`; `aryaos-capability-scan`; `aryaos-role` | Optional sensors disabled, CoT/GNSS core remains available |
| Hardware discovers itself | `shared_files/aryaos/aryaos-capability-scan`; scanner tests; `docs/config/device-roles.md` | “Conservative discovery”; never imply arbitrary hardware is recognized |
| Five mission roles | `shared_files/aryaos/aryaos-role`; device-role docs | air, maritime, C-UAS, multi-sensor, relay |
| ADSBee support | scanner and serial helpers; HIL tests; handoff 2026-08-10 | Identified by protocol, not USB ID alone |
| Broad SDR support | `aryaos-sdr`; `aryaos-capability-scan`; SDR docs | Name RTL-SDR, Airspy, HackRF, LimeSDR/SoapySDR; do not say every SDR/job combination works |
| Network SDR sharing | `docs/config/network-sdr.md` and related units | Explicitly opt-in, unauthenticated, firewall-closed by default |
| Spectrum/ZMeta and demod tools | `aryaos-spectrum-survey`; `aryaos-sdr-fm`; tests | Technical highlight; AM is experimental |
| ADS-B/UAT, AIS, RID, DJI, SiK, SAPIENT, ACARS, APRS, GNSS | package manifest, stage installs, role/capability helpers, deployment docs | Distinguish installed/available from auto-detected; position-bearing ACARS only |
| GNSS integrity indicators | `cockpit-gps` package, image floor, and package history | Say indicators/warnings, not certified anti-spoof protection |
| ForeFlight/GDL90 output | `gdlcot` manifest/role, `docs/deploy/foreflight-gdl90.md` | Converts CoT aircraft tracks; no claim of certified avionics |
| COTBridge hub and lanes | `docs/reference/software-suite.md`; `docs/admin/cotbridge-lanes.md`; config templates | Feeders to loopback bus, lanes to external destinations |
| TAK package import and enrollment | `docs/admin/aryaos-site.md`; import/enrollment helpers and HIL | Installs TLS and configures COTBridge output; certificate/hostname verification remains enabled |
| In-process reconnect | PyTAK/COTBridge floors; handoff 2026-08-13/14; HIL | Claim recovery from tested transient outages, not infinite availability |
| HTTPS field console | portal, CGI, Cockpit docs and image verifier | Routine controls in Cockpit; landing page is unauthenticated/read-only |
| Offline North America position map | `cockpit-aryaos` package floor and handoff 2026-07-21 | North America only; not the planned unified browser COP |
| Node-RED is optional and unprivileged | `docs/node-red.md`; service/stage config; security tests | Still ships; known default admin password must be rotated |
| Bluetooth PAN is local-only | `docs/bluetooth-pan.md`; firewall config | No NAT/forwarding; phone OS support varies |
| Persistent EMCON | `aryaos-radio`; silence unit; HIL | Blocks onboard Wi-Fi/Bluetooth; does not stop receive-only SDRs |
| GPS-disciplined time service | chrony config, PPS helpers, tests | “Where GNSS/PPS is available”; do not claim atomic/GPSDO accuracy |
| Image self-download | `aryaos-image-download` and Cockpit card/image verifier | Downloads matching release image; requires access to release source when fetching |
| Updates/support/backup/reset/zeroize | operation docs, helpers, lifecycle HIL | Zeroize is best-effort on flash; backup no-secrets omits defined secrets |
| Track recording and analysis | COTBridge recorder; `aryaos-tracks`; `aryaos-tracks-query` | Claim recording/query/export/purge only; browser replay remains roadmap |
| Nearby-node discovery | `aryaos-cot-detail`; `aryaos-neighbord`; portal/admin docs | Mesh SA local discovery; not centralized fleet management |
| Safe mode after short boots | `aryaos-safe-mode`; crash guard units; hardware docs/tests | Three short boots under configured threshold; keeps wired admin path available |
| Media longevity | zram/fstrim/tmpfs configs; media docs/HIL | “Reduces write amplification,” never “prevents media failure” |
| Firewall/fail2ban/SSH/TLS hardening | `docs/security.md`; firewalld assets; verifier/HIL | “Hardened”; never “unhackable,” FIPS validated, or STIG compliant |
| Signed packages and SBOMs | snstac sources/key; workflow SBOM steps; release assets | Every published image release should have both formats; verify stable asset list |
| Four-node closing fleet | `docs/agent-handoff.md` 2026-08-16; lifecycle evidence directory | State lab fleet and covered roles; do not imply a production fleet size |
| 165 local tests | handoff 2026-08-16 closing summary | Recheck against current HEAD if code changes before release |
| 5,000 events/node at about 675/s, zero write errors | handoff 2026-08-13 load test | Test evidence, not a guaranteed sustained capacity |
| Extended soak had no failed units/throttling/probe failures/restart growth | handoff 2026-08-13; burn-in summary | Say “during the measured window”; do not call it eight hours |
| Stable v2.1.19 available | Stable release workflow and GitHub release API | Publish only after tag is non-prerelease and `image-info.is_dev=false` |
| Fresh flash from v1 | Base OS rewrite and launch decision | No supported in-place v1 upgrade; preserve settings manually |
| ZeroTier replaced by Tailscale | base stage/history and VPN docs | Re-enrollment required; do not imply ZeroTier state migrates |
| CloudTAK removed | commit `fb61e25`; Node-RED and deployment docs | AOS2 connects to existing TAK Server or Mesh SA |
| dhbridge/kraktak excluded | `CHANGELOG.md`; verifier prohibition; public stage list | Do not mention private Gutcheck as a shipping public feature |

## Claims that must not appear

- Guaranteed 55-mile RF range.
- “Military-grade,” “unhackable,” FIPS validated, or STIG compliant.
- Guaranteed secure erasure from SD/NVMe flash.
- A supported amd64 image or macOS AryaOS Imager.
- In-place AryaOS 1 upgrade.
- A shipped unified all-sensor browser COP or integrated replay UI.
- Public inclusion of Gutcheck, dhbridge, or kraktak.
- Support for every SDR in every decoder mode.
