# Roadmap & next steps

Outstanding work and follow-ups for whoever picks up AryaOS next — human or
agent. Ordered by priority within each group. This is a living document: update
it as items land, and see [Agent handoff](agent-handoff.md) for the running
build/merge state and architecture invariants.

!!! note "Context"
    A large July 2026 sweep shipped the multi-domain COP model, the Cockpit
    admin cards, `gdltak` (ForeFlight/GDL90), the `@snstac/cockpit-shared`
    library, SBOMs, media-longevity tuning, the lifecycle tools (backup,
    factory reset, zeroize), and on-device offline docs. The items below are
    what remains.

## Start here — hardware burn-in

Several shipped features are verified only by `shellcheck`, `ansible
--syntax-check`, `mkdocs --strict`, and `verify-image.sh` static asserts. They
have **not been exercised on real hardware**. Flash the latest dev image and
run through them before relying on any of it in the field.

- [ ] **Destructive lifecycle paths.** On a throwaway box: a
      backup → restore round-trip, then `aryaos-factory-reset`, then
      `aryaos-zeroize` (confirm it reboots clean and the box stays usable). Watch
      the free-space overwrite duration. See [Factory reset](operations/factory-reset.md)
      and [Zeroize](operations/zeroize.md).
- [ ] **The Cockpit cards.** Exercise all AryaOS Site cards on hardware:
      support bundle, Node-RED password, Radios (RTL-SDR re-serial), device role,
      hotspot password, Tailscale join, backup/restore, factory reset, zeroize.
- [ ] **Expired-password first-login flow.** Confirm the Cockpit login handles
      the first-boot `chage -d 0 pi` expiry cleanly — this is the prerequisite for
      the first-login wizard below.
- [ ] **Media longevity.** Confirm zram swap activates (`swapon --show` shows a
      `/dev/zram0`), `fstrim.timer` is enabled, and logs are in RAM as expected.
- [ ] **Offline docs.** Confirm `https://<host>/docs/` serves and the portal QR
      resolves.
- [ ] Fold the above into `scripts/aryaos-test/tests/09-security.sh` (and a new
      `10-lifecycle.sh`) so future images regression-test them.

## Security follow-ups

- [ ] **Stronger zeroize guarantees.** The shipped `aryaos-zeroize` is
      best-effort by design (see [Zeroize](operations/zeroize.md)) — on
      wear-leveled flash, overwrite/TRIM cannot guarantee erasure. Two stronger
      options were deferred:
    - **Opt-in full-disk encryption (LUKS) → true crypto-erase.** The only hard
      guarantee on flash. Requires boot/initramfs work and a key-management story;
      makes zeroize an instant key-destroy.
    - **Scorched-earth zeroize mode.** A second mode that also wipes the
      rootfs/boot so a captured box reveals nothing and will not boot (requires
      reflash to reuse).
- [ ] **Dependabot backlog.** ~19 bot PRs across `aryaos`, `cockpit-aiscot`, and
      `cockpit-lincot` (dependency bumps, some majors — TypeScript, PatternFly,
      a Cockpit-lib refresh). Triage: merge safe patch/minor bumps, review majors.

## Platform & features

- [ ] **amd64 support** ([#129](https://github.com/snstac/aryaos/issues/129)).
      The pipeline is arm64-only pi-gen. Recommended first step: an
      `install-aryaos.sh` for any Debian 13 host — the signed apt repo + overlay
      deb already carry almost everything. Then a debos/bdebstrap amd64 image and
      a VM appliance.
- [ ] **First-login setup wizard.** A guided first-login flow (change password →
      set callsign → import TAK data package / set COT_URL → pick device role).
      All the pieces exist; blocked on the expired-password verification above.
- [ ] **Unified COP map on the portal.** `tar1090` shows only ADS-B. A portal
      map fusing ADS-B + AIS + drones + own position + Mesh SA neighbors
      (`/run/aryaos/neighbors.json` already exists) would make a box a
      self-contained COP for a browser-only user.
- [ ] **Track record & replay**
      ([#8](https://github.com/snstac/aryaos/issues/8),
      [#9](https://github.com/snstac/aryaos/issues/9)). Cleanest design: a
      Charontak recorder lane (it already sees all local CoT) writing rotating
      logs, with a portal page to download and replay — directly useful for
      wildland-fire after-action review.
- [ ] **SDR gain / PPM tuning UI.** The Radios card enumerates and re-serials
      dongles; gain and PPM are still file-only. Add them to the card.
- [ ] **`cockpit-gdltak` page** and a live ForeFlight/EFB validation for the new
      [GDL90 gateway](deploy/foreflight-gdl90.md).
- [ ] **CoT over BLE** ([#7](https://github.com/snstac/aryaos/issues/7)) — blocked
      on BLE advertising being broken image-wide on the trixie kernel / BCM4345C0
      ([#117](https://github.com/snstac/aryaos/issues/117)).

## Documentation

- [ ] **PyTAK / API reference** via `mkdocstrings` for the gateway internals.
- [ ] **Per-gateway deep-dive pages** and a **recipes/cookbook** section.
- [ ] **Versioned docs** (`mike`) once releases are cut from the docs.
- [ ] **Polish**: AryaOS branding CSS, social preview cards, rendered screenshots.

## Housekeeping

- [ ] **Close resolved issues.** [#21](https://github.com/snstac/aryaos/issues/21)
      (SDR web UI — done via the Radios card),
      [#51](https://github.com/snstac/aryaos/issues/51) (SBOM — done), and the
      image half of [#43](https://github.com/snstac/aryaos/issues/43)
      (ForeFlight/gdltak) are shipped and can be closed.
- [ ] **Current bugs.** [#93](https://github.com/snstac/aryaos/issues/93) (ADSBCOT
      Cockpit tab wrong header — quick fix) and
      [#94](https://github.com/snstac/aryaos/issues/94) (AIS-catcher serial port).
- [ ] **`python-networkmanager` → `python-sdbus-networkmanager`**
      ([#54](https://github.com/snstac/aryaos/issues/54)) — live tech debt in
      `stage-aryaos`.
- [ ] **Chroot vs Ansible stage drift.** Each stage exists twice (pi-gen
      `00-run.sh` + Ansible `tasks/`) and can diverge. Add a CI job that
      provisions a rootfs via Ansible and diffs it against the chroot result.
