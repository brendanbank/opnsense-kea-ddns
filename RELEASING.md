# Releasing opnsense-kea-ddns

## Files to Update

### 1. `net/kea-ddns/Makefile`

Bump `PLUGIN_VERSION`:

```makefile
PLUGIN_VERSION=		1.4
```

### 2. `net/kea-ddns/pkg-descr`

Add a new changelog entry at the top of the "Plugin Changelog" section:

```
1.4

Added:
* ...

Changed:
* ...
```

### 3. `README.md`

Update the version number in the installation example:

```sh
curl -LO https://github.com/brendanbank/opnsense-kea-ddns/releases/download/v1.4/os-kea-ddns-1.4.pkg
pkg install os-kea-ddns-1.4.pkg
```

Update the "Requirements" section if the supported OPNsense version range has changed.

### 4. Core patches (if needed)

If the core patch needs updating for a new or changed OPNsense release, see
[PATCHING.md](PATCHING.md) for the full workflow.

## Building the Package

The build runs on a remote FreeBSD/OPNsense host via SSH. From your workstation:

```sh
./scripts/build.sh <firewall-hostname>
```

This will:

1. Sync the local source tree to the remote host
2. Sparse-checkout `Mk/`, `Keywords/`, `Templates/`, and `Scripts/` from `opnsense/plugins` (first run only)
3. Run `make package` on the remote host
4. Test the upgrade and fresh-install paths (verifies core patches apply/reverse correctly)
5. Download the built `.pkg` to `dist/`
6. Update the GitHub Pages pkg repo in `docs/repo/` (if the directory exists)

The built package lands in `dist/os-kea-ddns-<version>.pkg`.

## Publishing a Release

### 1. Commit and tag

```sh
git add -A
git commit -m "Release v<version>"
git tag v<version>
git push origin main --tags
```

### 2. Update GitHub Pages pkg repo

The build script automatically regenerates `docs/repo/` with the new `.pkg` and
pkg repo metadata (`meta.conf`, `packagesite.*`, `data.*`). Commit and push the
updated `docs/` directory:

```sh
git add docs/repo/
git commit -m "Update pkg repo for v<version>"
git push
```

This updates the GitHub Pages-hosted pkg repository, which allows the OPNsense
firmware UI to display plugin details (the repo is registered during package
install via `+POST_INSTALL.post`).

### 3. Create a GitHub Release

Go to the repository's Releases page and create a new release from the tag.
Attach `dist/os-kea-ddns-<version>.pkg` as a release asset.

## Checklist

- [ ] Bump `PLUGIN_VERSION` in `net/kea-ddns/Makefile`
- [ ] Add changelog entry in `net/kea-ddns/pkg-descr`
- [ ] Update version in `README.md` install example
- [ ] Add/update core patches if needed (`./scripts/generate-patch.sh <tag>`, see [PATCHING.md](PATCHING.md))
- [ ] Run `./scripts/build.sh <firewall-hostname>` and verify tests pass
- [ ] Commit, tag (`v<version>`), and push with tags
- [ ] Commit and push updated `docs/repo/`
- [ ] Create GitHub Release with `.pkg` attached
