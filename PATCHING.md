# Core Patching for opnsense-kea-ddns

The patch files live in `net/kea-ddns/src/opnsense/data/kea-ddns/patches/` and
are named by OPNsense series (e.g., `26.1.patch`). The install hooks detect the
running series from `/usr/local/opnsense/version/core` (`product_series`) and
select the matching patch.

A patch may need updating for:

- **New major release** (e.g., 26.7) — the core Kea files are likely restructured
  or changed and need a new patch file.
- **Minor/point release** (e.g., 26.1.2 to 26.1.3) — an OPNsense update within
  the same series can change the patched core files, causing the existing patch
  to no longer apply cleanly. Since minor releases share the same series name,
  the existing `<series>.patch` file must be updated in place.

After an OPNsense update, if users report that the patch fails to apply, or
if `+POST_INSTALL.post` logs a warning, the patch needs to be regenerated
against the updated core files.

## Patched Files

The patch modifies three files under `/usr/local` on the firewall:

- `etc/inc/plugins.inc.d/kea.inc` — adds `plugins_run('kea_ddns_generate')` hook and `kea-dhcp-ddns` syslog facility
- `opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php` — adds `plugins_run('kea_dhcpv4_config')` overlay loop
- `opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php` — adds `plugins_run('kea_dhcpv6_config')` overlay loop

## Code to Insert

The following code blocks are inserted into the `b/` copies when generating a
patch. The insertion points depend on the OPNsense release, but the code itself
is the same across all versions.

### `etc/inc/plugins.inc.d/kea.inc`

**Hook 1 — DDNS config generation and daemon toggle.** Insert inside
`kea_configure_do()`, after the line that calls
`(new \OPNsense\Kea\KeaCtrlAgent())->generateConfig();`:

```php
        /* let plugins generate supplementary configs (e.g. kea-dhcp-ddns.conf) */
        $ddnsResults = plugins_run('kea_ddns_generate');
        $ddnsEnabled = !empty($ddnsResults);
        /* enable/disable DDNS daemon in keactrl.conf */
        $keactrl = '/usr/local/etc/kea/keactrl.conf';
        $keactrlContent = @file_get_contents($keactrl);
        if ($keactrlContent !== false) {
            $keactrlContent = preg_replace(
                '/^dhcp_ddns=.*$/m',
                'dhcp_ddns=' . ($ddnsEnabled ? 'yes' : 'no'),
                $keactrlContent
            );
            @file_put_contents($keactrl, $keactrlContent);
        }
```

**Hook 2 — syslog facility.** In `kea_syslog()`, add `'kea-dhcp-ddns'` to the
facility array:

```php
    $logfacilities['kea'] = ['facility' => ['kea-dhcp4', 'kea-dhcp6', 'kea-ctrl-agent', 'kea-dhcp-ddns']];
```

(replaces the existing line that only lists `kea-dhcp4`, `kea-dhcp6`, `kea-ctrl-agent`)

### `opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php`

**DHCPv4 config overlay.** Insert inside `generateConfig()`, just before the
`File::file_put_contents($target, ...)` call at the end of the method:

```php
        /* allow plugins to overlay config (e.g. DDNS parameters) */
        foreach (plugins_run('kea_dhcpv4_config') as $overlay) {
            if (isset($overlay['global'])) {
                $cnf['Dhcp4'] = array_merge($cnf['Dhcp4'], $overlay['global']);
            }
            if (isset($overlay['subnets'])) {
                foreach ($cnf['Dhcp4']['subnet4'] as &$subnet) {
                    if (isset($overlay['subnets'][$subnet['subnet']])) {
                        $subnet = array_merge($subnet, $overlay['subnets'][$subnet['subnet']]);
                    }
                }
                unset($subnet);
            }
        }
```

### `opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php`

**DHCPv6 config overlay.** Same pattern as DHCPv4 — insert just before the
`File::file_put_contents($target, ...)` call:

```php
        /* allow plugins to overlay config (e.g. DDNS parameters) */
        foreach (plugins_run('kea_dhcpv6_config') as $overlay) {
            if (isset($overlay['global'])) {
                $cnf['Dhcp6'] = array_merge($cnf['Dhcp6'], $overlay['global']);
            }
            if (isset($overlay['subnets'])) {
                foreach ($cnf['Dhcp6']['subnet6'] as &$subnet) {
                    if (isset($overlay['subnets'][$subnet['subnet']])) {
                        $subnet = array_merge($subnet, $overlay['subnets'][$subnet['subnet']]);
                    }
                }
                unset($subnet);
            }
        }
```

## Using the opnsense/core Repository

Keep a local clone of opnsense/core with the upstream remote configured. This
lets you check out the exact core files for any release tag without needing SSH
access to a firewall.

**Initial setup** (one time):

```sh
git clone https://github.com/opnsense/core.git ../core
cd ../core
```

Or if you already have a fork:

```sh
git remote add upstream https://github.com/opnsense/core.git
```

**Fetch the latest tags** (releases are tagged as `26.1.2`, `26.1.3`, etc.):

```sh
git fetch upstream --tags
git tag -l '26.1*' | sort -V     # list available 26.1.x releases
```

**Check out the core files for a specific release:**

```sh
git checkout 26.1.2 -- \
    src/etc/inc/plugins.inc.d/kea.inc \
    src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php \
    src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php
```

**Test the existing patch against those files:**

```sh
cd src && patch --dry-run --forward --strip=1 \
    < ../opnsense-kea-ddns/net/kea-ddns/src/opnsense/data/kea-ddns/patches/26.1.patch
```

If it applies cleanly, no patch update is needed. Restore your working tree
afterward:

```sh
git checkout <your-branch> -- \
    src/etc/inc/plugins.inc.d/kea.inc \
    src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php \
    src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php
```

## Generating a New or Updated Patch

Use the `generate-patch.sh` script to automate patch creation:

```sh
./scripts/generate-patch.sh <release-tag> [core-repo-path]
```

Examples:

```sh
./scripts/generate-patch.sh 26.1.2            # uses ../core by default
./scripts/generate-patch.sh 26.1.3 /path/to/core
```

The script will:

1. Extract the three core files from the specified tag via `git show`
2. Apply the DDNS hook code to copies of the files
3. Generate a unified diff
4. Save it as `patches/<series>.patch` (series derived from tag, e.g., `26.1.2` -> `26.1`)
5. Verify the patch applies and reverses cleanly

### Manual patch generation

If the script fails (e.g., because the anchor points in the core files have
changed significantly), follow the manual process:

1. **Check out the clean core files** from the target release tag (see above).

2. **Copy them into an `a/` and `b/` directory structure** for diffing:

   ```sh
   mkdir -p /tmp/patch-work/{a,b}/etc/inc/plugins.inc.d
   mkdir -p /tmp/patch-work/{a,b}/opnsense/mvc/app/models/OPNsense/Kea
   cp src/etc/inc/plugins.inc.d/kea.inc /tmp/patch-work/a/etc/inc/plugins.inc.d/
   cp src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php /tmp/patch-work/a/opnsense/mvc/app/models/OPNsense/Kea/
   cp src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php /tmp/patch-work/a/opnsense/mvc/app/models/OPNsense/Kea/
   cp -r /tmp/patch-work/a/* /tmp/patch-work/b/
   ```

3. **Apply the hooks** to the `b/` copies using the code blocks from the
   "Code to Insert" section above.

4. **Generate the unified diff:**

   ```sh
   cd /tmp/patch-work
   diff -u a/etc/inc/plugins.inc.d/kea.inc b/etc/inc/plugins.inc.d/kea.inc > new.patch
   diff -u a/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php \
           b/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php >> new.patch
   diff -u a/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php \
           b/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php >> new.patch
   ```

5. **Save the patch** as `net/kea-ddns/src/opnsense/data/kea-ddns/patches/<series>.patch`
   (e.g., `26.1.patch` or `27.1.patch`).

6. **Verify round-trip** — the install and uninstall hooks use `patch --forward`
   and `patch --reverse` respectively, so confirm both directions apply cleanly.

## After an OPNsense Minor Release

When a point release lands (e.g., 26.1.3), check whether the existing patch
still applies. The quickest way is to regenerate and compare:

```sh
./scripts/generate-patch.sh 26.1.3
```

If the script succeeds and `git diff` shows no changes to the patch file, no
action is needed.

Alternatively, test manually:

```sh
# Using the core repo:
cd ../core
git fetch upstream --tags
git checkout 26.1.3 -- \
    src/etc/inc/plugins.inc.d/kea.inc \
    src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php \
    src/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php
cd src && patch --dry-run --forward --strip=1 \
    < ../opnsense-kea-ddns/net/kea-ddns/src/opnsense/data/kea-ddns/patches/26.1.patch

# Or directly on a firewall that has been updated:
ssh <firewall-hostname> 'cd /usr/local && patch --dry-run --forward --strip=1' \
    < net/kea-ddns/src/opnsense/data/kea-ddns/patches/26.1.patch
```

If the patch no longer applies, regenerate it with the script and publish a new
plugin release.

## Package Install/Uninstall Hooks

The package uses three hook scripts that handle patching automatically:

| Script | When | What it does |
|---|---|---|
| `+PRE_INSTALL.pre` | Before upgrade install | Reverses the current core patch so POST_INSTALL can apply the (possibly updated) patch cleanly |
| `+POST_INSTALL.post` | After install | Detects OPNsense series, applies the matching core patch, registers the plugin with firmware, adds the GitHub Pages pkg repo |
| `+PRE_DEINSTALL.pre` | Before removal | Reverses the core patch, deregisters the plugin, removes the pkg repo config |
