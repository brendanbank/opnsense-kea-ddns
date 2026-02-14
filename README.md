# opnsense-kea-ddns

Kea DHCP-DDNS plugin for OPNsense. Adds Dynamic DNS (RFC 2136) support for the
Kea DHCP server, enabling automatic DNS registration of DHCP leases.

This plugin requires a small core patch (~25 lines) that adds `plugins_run()`
hook points to the Kea DHCP configuration pipeline. All DDNS logic lives in the
plugin itself.

## Background

OPNsense core does not yet support Kea DHCP-DDNS. The upstream PR
([opnsense/core#9401](https://github.com/opnsense/core/pull/9401)) is stalled
due to scope concerns. This repo packages a working implementation as a
standalone plugin with a minimal core patch, suitable for self-hosted
deployments.

## Features

- TSIG key management (HMAC-MD5 through HMAC-SHA512)
- Forward and reverse DNS zone configuration with per-zone DNS server and TSIG key
- Per-subnet DDNS policy (send updates, qualifying suffix, conflict resolution)
- Automatic config injection into `kea-dhcp4.conf` via `plugins_run()` hooks
- `kea-dhcp-ddns` daemon configuration generation (`kea-dhcp-ddns.conf`)
- Manual config mode for direct editing of `kea-dhcp-ddns.conf`
- Log file viewer under Services > Kea DDNS

## Requirements

- OPNsense 25.1 or later (tested against current master)
- Kea DHCP server enabled and configured

## Repository Structure

```
opnsense-kea-ddns/
├── core-patches/           # Minimal core patch (plugins_run hooks)
│   └── 0001-kea-add-plugins_run-hooks-for-DDNS-plugin-support.patch
├── net/kea-ddns/           # OPNsense plugin (standard plugin layout)
│   ├── Makefile
│   ├── pkg-descr
│   └── src/
│       ├── etc/inc/plugins.inc.d/kea_ddns.inc
│       └── opnsense/mvc/app/
│           ├── controllers/OPNsense/KeaDdns/
│           ├── models/OPNsense/KeaDdns/
│           └── views/OPNsense/KeaDdns/
├── scripts/
│   ├── install.sh          # Automated installer
│   └── uninstall.sh        # Clean removal
└── README.md
```

## Installation

### Quick install

Copy this repo to your OPNsense firewall and run the install script:

```sh
# On the firewall
git clone https://github.com/brendanbank/opnsense-kea-ddns.git
cd opnsense-kea-ddns
sh scripts/install.sh
```

### Manual install

1. **Apply the core patch** (adds `plugins_run()` hooks to Kea):

   ```sh
   cd /usr/local
   patch -p1 < core-patches/0001-kea-add-plugins_run-hooks-for-DDNS-plugin-support.patch
   ```

2. **Copy plugin files** into place:

   ```sh
   cp -R net/kea-ddns/src/etc/inc/plugins.inc.d/kea_ddns.inc \
       /usr/local/etc/inc/plugins.inc.d/
   cp -R net/kea-ddns/src/opnsense/mvc/app/controllers/OPNsense/KeaDdns \
       /usr/local/opnsense/mvc/app/controllers/OPNsense/
   cp -R net/kea-ddns/src/opnsense/mvc/app/models/OPNsense/KeaDdns \
       /usr/local/opnsense/mvc/app/models/OPNsense/
   cp -R net/kea-ddns/src/opnsense/mvc/app/views/OPNsense/KeaDdns \
       /usr/local/opnsense/mvc/app/views/OPNsense/
   ```

3. **Restart Kea**:

   ```sh
   configctl kea restart
   ```

4. Navigate to **Services > Kea DDNS** in the web UI.

## Uninstallation

```sh
sh scripts/uninstall.sh
```

Or manually reverse the steps above and remove the plugin directories.

## How It Works

The core patch adds two hook points:

- **`kea_dhcpv4_config`** — called during `KeaDhcpv4::generateConfig()`, allows
  the plugin to overlay DDNS parameters (global and per-subnet) into
  `kea-dhcp4.conf`
- **`kea_ddns_generate`** — called during `kea_configure_do()`, triggers the
  plugin to generate `kea-dhcp-ddns.conf` and toggles the DDNS daemon in
  `keactrl.conf`

This is the same `plugins_run()` pattern already used in OPNsense core (e.g.,
Kea exports `static_mapping` which Unbound/Dnsmasq consume).

## OPNsense Upgrades

OPNsense firmware upgrades will overwrite the patched core files. After an
upgrade, re-run the install script or re-apply the core patch. The plugin files
in the `KeaDdns` directories are not touched by core upgrades.

## Credits

- Plugin implementation: [Brendan Bank](https://github.com/brendanbank)
- Original Kea DDNS core work: [Rui Fung Yip](https://github.com/ruifung)
  ([opnsense/core#9401](https://github.com/opnsense/core/pull/9401))

## License

BSD 2-Clause — see source files for the full license text.
