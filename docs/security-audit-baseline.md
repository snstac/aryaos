# Security audit baseline (2026-05-24)

GitHub Dependabot reported **25 open alerts** on `main` at push time (4 high, 18 moderate, 3 low). Re-check after fixes: **Security → Dependabot** on GitHub.

| Manifest | Local scan | Fix applied |
|----------|------------|-------------|
| `shared_files/cloudtak/shim/package-lock.json` | 3 moderate (`brace-expansion`, `protobufjs`, `qs`) | `npm audit fix` |
| `shared_files/node-red/package.json` | Was 48 issues without lock (8 critical, 18 high) | Removed spurious deps; lockfile + overrides; `npm ci --omit=dev`; **0 critical**, 7 high (patched transitive; audit noise) |
| `docs/requirements.txt` | Stale 2023 pins | `pip-compile --upgrade` + `pip-audit` clean |
| `.github/workflows/*` | Deprecated `create-release@master` | Modernized release action |

Export open alerts when `gh` is available:

```bash
gh api repos/snstac/aryaos/dependabot/alerts?state=open \
  --jq '.[] | [.number, .security_advisory.severity, .dependency.package.name, .dependency.manifest_path] | @tsv'
```
