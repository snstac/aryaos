# Vendored dhbridge package

[snstac/dhbridge](https://github.com/snstac/dhbridge) is a **private** repository. Pi-gen and CI image builds install `dhbridge_*_all.deb` from this directory instead of downloading from GitHub.

Refresh after an upstream release (requires `gh` auth):

```bash
gh release download v0.2.2 -R snstac/dhbridge -p 'dhbridge_0.2.0-3_all.deb' -D shared_files/dhbridge/
```

Update `dhbridge_version` / `dhbridge_deb` in [`vars.yml`](../../vars.yml) and the pi-gen workflow path check in [`.github/workflows/pi-gen.yml`](../../.github/workflows/pi-gen.yml).
