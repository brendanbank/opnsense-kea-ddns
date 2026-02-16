# Project: opnsense-kea-ddns

OPNsense plugin for Kea DHCP Dynamic DNS (DDNS) support.

## OPNsense Versioning

OPNsense uses YY.MM versioning with major releases in January (.1) and July (.7).
Tag suffixes: `.a` = alpha, `.b` = beta, `.r` = release candidate, then GA, then `.1`/`.2` = point releases.

## Project Structure

```
opnsense-kea-ddns/
├── net/kea-ddns/                    # OPNsense plugin (standard plugin layout)
│   ├── Makefile                     # PLUGIN_VERSION lives here
│   ├── pkg-descr                    # Package description and changelog
│   ├── +PRE_INSTALL.pre             # Reverses core patch before upgrade
│   ├── +POST_INSTALL.post           # Applies core patch, registers plugin
│   ├── +PRE_DEINSTALL.pre           # Reverses core patch, deregisters plugin
│   └── src/
│       ├── etc/inc/plugins.inc.d/kea_ddns.inc
│       └── opnsense/
│           ├── data/kea-ddns/patches/   # Per-release core patches (26.1.patch, etc.)
│           ├── mvc/app/
│           │   ├── controllers/OPNsense/KeaDdns/
│           │   ├── models/OPNsense/KeaDdns/
│           │   └── views/OPNsense/KeaDdns/
│           └── service/templates/OPNsense/Syslog/
├── scripts/
│   ├── build.sh                     # Remote package builder
│   ├── generate-patch.sh            # Automated core patch generation
│   ├── install.sh                   # Dev installer
│   ├── uninstall.sh                 # Dev uninstaller
│   ├── functional_test.sh           # Functional test runner
│   └── tests/                       # Test scripts
├── docs/                            # Sphinx docs + GitHub Pages pkg repo
│   └── repo/                        # Pkg repo (auto-updated by build.sh)
├── RELEASING.md                     # Release checklist and workflow
├── PATCHING.md                      # Core patch docs and hook code reference
└── README.md
```

## Core Patching

The plugin patches three OPNsense core files to add hook points:

- `kea.inc` — `plugins_run('kea_ddns_generate')` + syslog facility
- `KeaDhcpv4.php` — `plugins_run('kea_dhcpv4_config')` overlay loop
- `KeaDhcpv6.php` — `plugins_run('kea_dhcpv6_config')` overlay loop

Patches are per OPNsense series (e.g., `26.1.patch`). The install hooks
auto-detect the running series and apply the correct patch.

Use `./scripts/generate-patch.sh <tag>` to generate patches from opnsense/core tags.
Requires a local clone of opnsense/core (default: `../core`).

## Build and Release

See [RELEASING.md](RELEASING.md) for the full checklist. Summary:

1. Bump `PLUGIN_VERSION` in `net/kea-ddns/Makefile`
2. Update changelog in `net/kea-ddns/pkg-descr`
3. Update version in `README.md` install example
4. `./scripts/build.sh <firewall-hostname>` — builds, tests, downloads .pkg
5. Commit, tag `v<version>`, push
6. Commit and push `docs/repo/`
7. Create GitHub Release with .pkg attached
