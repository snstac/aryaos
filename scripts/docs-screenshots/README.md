# Documentation screenshots

Regenerate the UI screenshots used in the docs from the **real front-end code**,
with no hardware or running Cockpit backend. Rendered by headless Chromium
(Playwright) using representative, canned data.

## Run

From the repository root:

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r scripts/docs-screenshots/requirements.txt
playwright install chromium
python scripts/docs-screenshots/capture.py
```

Output PNGs are written into `docs/media/screenshots/`. Review the diff before
committing.

## What it captures

| Screenshot | Source | Notes |
|------------|--------|-------|
| `portal-landing.png`, `portal-landing-mobile.png` | in-repo `shared_files/aryaos/html` | Status CGI stubbed with realistic JSON |
| `aryaos-site-cockpit.png` | sibling repo `../cockpit-aryaos` | Rendered against `mock-cockpit.js` (a stub of `window.cockpit`) |

The AryaOS Site page is vanilla JS that calls a global `window.cockpit`;
[`mock-cockpit.js`](mock-cockpit.js) supplies that with canned `spawn`/`file`
responses. Edit the canned data there and in `capture.py` to change what the
screenshots show.

## React plugins (lane editor, per-gateway pages)

The React/TypeScript plugins (`cockpit-charontak`, `cockpit-aiscot`, …) bundle
the **real** Cockpit client, which expects a live `cockpit-ws` backend, so the
`window.cockpit` stub above does not apply. To screenshot them, rebuild the
plugin with `cockpit` aliased to a mock module, then serve `dist/`:

1. In the plugin repo, replace `pkg/lib/cockpit.js` with a mock default export
   exposing `spawn`, `file`, `gettext`, and `dbus` (see `mock-cockpit.js` for the
   shape), then `./build.js` (non-production, so `dist/` is uncompressed).
2. Serve `dist/` and screenshot as above.

This path is manual today; automate it here if the plugin screenshots need to be
refreshed regularly.

## Honesty note

These are the real UI, rendered with representative data — not captures from a
live field device. Values shown (hostname, IPs, tracks) are illustrative. A
live capture would differ only in the specific data.
