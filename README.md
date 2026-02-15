# opnsense-kea-ddns

> **WARNING:** This plugin patches OPNsense core Kea files to add DDNS hook
> points. OPNsense firmware upgrades may overwrite these patches, requiring
> reinstallation. While the plugin auto-applies and reverses patches on
> install/uninstall, using core patches in production carries inherent risk —
> future OPNsense updates could change the patched files in incompatible ways,
> potentially breaking your DHCP configuration. Use at your own risk and always
> test after OPNsense upgrades.

Kea DHCP-DDNS plugin for OPNsense. Adds Dynamic DNS (RFC 2136) support for the
Kea DHCP server, enabling automatic DNS registration of DHCPv4 and DHCPv6 leases.

This plugin requires a small core patch that adds `plugins_run()` hook points
to the Kea DHCP configuration pipeline. All DDNS logic lives in the plugin
itself. The package auto-detects the OPNsense release and applies the correct
per-release patch.

## Background

OPNsense core does not yet support Kea DHCP-DDNS. There is an open upstream PR
([opnsense/core#9401](https://github.com/opnsense/core/pull/9401)) to add this
to core. This repo packages a working implementation as a standalone plugin with
a minimal core patch, suitable for self-hosted deployments.

## Features

- TSIG key management (HMAC-MD5 through HMAC-SHA512)
- Forward and reverse DNS zone configuration with per-zone DNS server and TSIG key
- Per-subnet DDNS policy for both DHCPv4 and DHCPv6 (send updates, qualifying suffix, conflict resolution)
- Automatic config injection into `kea-dhcp4.conf` and `kea-dhcp6.conf` via `plugins_run()` hooks
- `kea-dhcp-ddns` daemon configuration generation (`kea-dhcp-ddns.conf`)
- DHCID conflict resolution modes (RFC 4703)
- Manual config mode for direct editing of `kea-dhcp-ddns.conf`
- Log file viewer under Services > Kea DDNS

## Requirements

- OPNsense 26.1 (tested on 26.1.2)
- Kea DHCP server enabled and configured

## Documentation

Full documentation is available at https://brendanbank.github.io/opnsense-kea-ddns/
(also in [docs/keaddns.md](docs/keaddns.md)).

## Installation

Download the latest `.pkg` from [GitHub Releases](https://github.com/brendanbank/opnsense-kea-ddns/releases)
and install it on your firewall:

```sh
curl -LO https://github.com/brendanbank/opnsense-kea-ddns/releases/download/v1.3.1/os-kea-ddns-1.3.1.pkg
pkg install os-kea-ddns-1.3.1.pkg
```

Replace the version number with the latest available release.

## Uninstallation

```sh
pkg remove os-kea-ddns
```

This removes all plugin files and reverses the core patch.

## Repository Structure

```
opnsense-kea-ddns/
├── core-patches/                # Reference core patch
├── docs/                        # Documentation (RST source, auto-generated MD and HTML)
├── net/kea-ddns/                # OPNsense plugin (standard plugin layout)
│   ├── +PRE_INSTALL.pre         # Pre-install script (reverses core patch before upgrade)
│   ├── +POST_INSTALL.post       # Post-install script (applies core patch, adds pkg repo)
│   ├── +PRE_DEINSTALL.pre       # Pre-deinstall script (reverses core patch, removes pkg repo)
│   ├── Makefile
│   ├── pkg-descr
│   └── src/
│       ├── etc/inc/plugins.inc.d/kea_ddns.inc
│       └── opnsense/
│           ├── data/kea-ddns/patches/   # Per-release core patches (26.1, 26.7)
│           ├── mvc/app/
│           │   ├── controllers/OPNsense/KeaDdns/
│           │   ├── models/OPNsense/KeaDdns/
│           │   └── views/OPNsense/KeaDdns/
│           └── service/templates/OPNsense/Syslog/
├── scripts/
│   ├── build.sh                 # Package builder
│   ├── install.sh               # Dev installer (applies patch + copies files)
│   ├── uninstall.sh             # Dev uninstaller
│   ├── isc2kea.py               # ISC DHCP to Kea DDNS migration tool
│   ├── functional_test.sh       # Functional test runner
│   └── tests/                   # Test scripts
└── README.md
```

## How It Works

The core patch adds three hook points:

- **`kea_ddns_generate`** — called during `kea_configure_do()`, triggers the
  plugin to generate `kea-dhcp-ddns.conf` and toggles the DDNS daemon in
  `keactrl.conf`
- **`kea_dhcpv4_config`** — called during `KeaDhcpv4::generateConfig()`, allows
  the plugin to overlay DDNS parameters (global and per-subnet) into
  `kea-dhcp4.conf`
- **`kea_dhcpv6_config`** — called during `KeaDhcpv6::generateConfig()`, same
  as above but for `kea-dhcp6.conf`

This is the same `plugins_run()` pattern already used in OPNsense core (e.g.,
Kea exports `static_mapping` which Unbound/Dnsmasq consume).

## OPNsense Upgrades

OPNsense firmware upgrades may overwrite the patched core files. After an
upgrade, reinstall the package to reapply the hooks. The plugin files
in the `KeaDdns` directories are not touched by core upgrades.

## Credits

- Plugin implementation: [Brendan Bank](https://github.com/brendanbank)
- Original Kea DDNS core work: [Rui Fung Yip](https://github.com/ruifung)
  ([opnsense/core#9401](https://github.com/opnsense/core/pull/9401))

## License

BSD 2-Clause — see source files for the full license text.
