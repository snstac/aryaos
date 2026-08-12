# Vendored suite design assets

Source: **`snstac/design-system`** (private)
Pinned revision: **`f8bdd10028f55f75c83f438d34e6ed29527d6d75`**
Vendored: 2026-07-29

The design-system consumption model is explicit - pin a reviewed commit, copy
the files in, and record the revision here. Do **not** hotlink that repository
at request time: a public site must not depend on GitHub availability or on a
private repo.

## What was copied

| Here | From |
|------|------|
| `tokens/suite-tokens.css`, `.json` | `runtime/suite/` |
| `logo/*.svg`, `logo/png/*` | `runtime/suite/` |
| `fonts/*.woff2`, `OFL-1.1.txt`, `THIRD_PARTY_NOTICES.md` | `runtime/fonts/` |
| `css/fonts.css`, `css/suite-primitives.css` | `implementation/css/` |
| `AryaOS-Suite-Design-Guide.html` | `source/` |

## Local adjustments

Both are sanctioned by the upstream README, which describes `implementation/`
as *copyable CSS ... adjusted for the consumer's public asset path*.

1. **Asset paths.** `../../runtime/fonts/` becomes `../fonts/`, and the token
   import becomes `../tokens/suite-tokens.css`, to match this flat layout.

2. **Arya-family surfaces.** The shared `.sns-surface-paper` /
   `.sns-surface-console` are defined against the **&kit** palette
   (`--sns-kit-paper` `#F2F4EE`, `--sns-kit-ink` `#0B0C0A`). AryaOS is an
   **Arya**-family property, whose grounds are Paper `#F2EFE7` on Ink `#12211A`.
   Adopting them verbatim would put an Arya property on the wrong paper, so
   family-scoped overrides are appended to `css/suite-primitives.css`.
   **Raised upstream** so the shared primitives can become family-aware instead
   of every Arya consumer patching this locally.

## Deviations from the guide

**Operator surfaces use 48px hit targets, not the kit's 44px.** AryaOS Cockpit
plugins are driven in the field with gloves on; that standard predates this kit
and was set from use. Documentation is a *read* surface and follows the kit at
44px. Recorded so it reads as deliberate rather than as drift.

## Re-syncing

Copy the table above from a newer reviewed commit, re-apply the two local
adjustments, update the revision here, then run this repository's own
validation - `mkdocs build --strict` - as the upstream RUNBOOK requires of a
consumer.

## How this consumer applies the tokens

The upstream model is `<body class="sns-suite-frame sns-surface-paper">`. This
site runs Material for MkDocs, which owns its own layout, so applying
`.sns-suite-frame` to `body` would fight it (`min-height: 100vh`, background and
`box-sizing` on every descendant).

Instead `docs/stylesheets/suite.css` **bridges** the tokens onto the variables
Material actually reads. Same values, same single source; only the delivery
differs. The `.sns-surface-*` classes remain available for any surface that is
not a Material page.
