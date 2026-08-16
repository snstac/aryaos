# AOS2 publication checklist (internal)

## Stable release gate

- [ ] `main` is the intended release commit and `/etc/aryaos-version` source is
      `2.1.19`.
- [ ] Dispatch `pi-gen.yml` with `release=true` and `release_tag=v2.1.19`.
- [ ] Build, mounted-image verification, SBOM generation, and publication all
      complete successfully.
- [ ] GitHub shows `v2.1.19` as a normal release, not a draft or prerelease.
- [ ] The tag resolves to the intended commit.
- [ ] Release assets include the `.img.xz`, `aryaos-overlay_2.1.19_all.deb`,
      `image-info.json`, SPDX JSON, and CycloneDX JSON.
- [ ] `image-info.json` reports tag `v2.1.19` and `is_dev: false`.
- [ ] AryaOS Imager resolves `v2.1.19` as **latest release** while the timestamped
      dev build remains **latest dev**.
- [ ] Update the GitHub release body with the announcement, migration warning,
      flash instructions, and credits.

## Editorial gate

- [ ] Recheck every quantitative statement against `claims-ledger.md` and the
      final stable workflow evidence.
- [ ] Confirm all channels say AryaOS 2 / AOS2 and stable `v2.1.19`.
- [ ] Confirm all v1 migration copy says fresh flash and does not imply restore
      compatibility.
- [ ] Confirm specialist SDR features retain their trust/experimental caveats.
- [ ] Confirm zeroize is always called best-effort on flash.
- [ ] Confirm private Gutcheck, dhbridge, and kraktak are not shipping claims.
- [ ] Confirm roadmap features are absent or explicitly labeled not shipped.
- [ ] Run the strict MkDocs build and inspect links.
- [ ] Review the announcement once in desktop and mobile layouts.

## Existing launch assets

| Use | Asset |
|---|---|
| Primary brand mark | `docs/brand/logo/mark-aryaos.svg` or reverse variant |
| Product configuration marks | `docs/brand/logo/mark-aryaair.svg`, `mark-aryasea.svg`, `mark-aryauas.svg`, `mark-dragonegg.svg` |
| Field hardware | `docs/media/backpack.png` and existing AirTAK photographs |
| Command deck | `docs/media/screenshots/portal-landing.png` and mobile variant |
| Admin console | `docs/media/screenshots/aryaos-site-cockpit.png` |
| CoT routing | `docs/media/screenshots/cotbridge-lane-editor.png` |
| Gateway UI | `docs/media/screenshots/gateway-aiscot.png` |
| TAK result | `docs/media/atak_screenshot_with_pytak_logo.jpg` and `uas_screenshot.png` |

Before public reuse, visually inspect older photographs/screenshots for obsolete
branding, credentials, IP addresses, callsigns, or v1 UI. Do not imply that an
old screenshot depicts the AOS2 console.

## Suggested announcement sequence

1. Publish and verify stable `v2.1.19`.
2. Confirm AryaOS Imager stable-channel resolution.
3. Publish the long announcement and feature matrix.
4. Update README/docs home and GitHub release body.
5. Send the launch email.
6. Publish LinkedIn and the X thread with the same stable links.
7. Share partner-newsletter copy with funders and integrators.
8. Monitor release downloads, broken links, installation reports, and migration
   questions; route corrections back through the canonical matrix and FAQ.
