#!/bin/sh

# Install script for opnsense-kea-ddns
# Applies the core patch and installs the plugin on a running OPNsense system.
#
# Usage: ssh root@firewall 'sh -s' < scripts/install.sh
#   or:  Copy this repo to the firewall and run: sh scripts/install.sh

set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
REPO_DIR=$(dirname "$SCRIPT_DIR")

echo "==> opnsense-kea-ddns installer"
echo ""

# --- Step 1: Apply core patch ---
CORE_SRC="/usr/local"
PATCH_FILE="$REPO_DIR/core-patches/0001-kea-add-plugins_run-hooks-for-DDNS-plugin-support.patch"

KEA_INC="$CORE_SRC/etc/inc/plugins.inc.d/kea.inc"
KEA_DHCPV4="$CORE_SRC/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php"
KEA_DHCPV6="$CORE_SRC/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv6.php"

# Check if hooks are already present (all three files must be patched)
if grep -q 'kea_ddns_generate' "$KEA_INC" 2>/dev/null && \
   grep -q 'kea_dhcpv4_config' "$KEA_DHCPV4" 2>/dev/null && \
   grep -q 'kea_dhcpv6_config' "$KEA_DHCPV6" 2>/dev/null; then
    echo "    Core hooks already applied, skipping patch."
else
    echo "==> Applying core hooks patch..."
    # The git-format patch has paths like a/src/etc/... — strip=2 removes both a/ and src/
    # Use --forward to skip already-applied hunks (partial upgrade case)
    cd "$CORE_SRC"
    patch --forward --strip=2 < "$PATCH_FILE" || true
    # Verify all three hooks are present after patching
    PATCH_OK=true
    grep -q 'kea_ddns_generate' "$KEA_INC" 2>/dev/null || PATCH_OK=false
    grep -q 'kea_dhcpv4_config' "$KEA_DHCPV4" 2>/dev/null || PATCH_OK=false
    grep -q 'kea_dhcpv6_config' "$KEA_DHCPV6" 2>/dev/null || PATCH_OK=false
    if [ "$PATCH_OK" = "true" ]; then
        echo "    Core hooks applied successfully."
    else
        echo "ERROR: Core patch incomplete. Missing hooks in:"
        grep -q 'kea_ddns_generate' "$KEA_INC" 2>/dev/null || echo "  - $KEA_INC"
        grep -q 'kea_dhcpv4_config' "$KEA_DHCPV4" 2>/dev/null || echo "  - $KEA_DHCPV4"
        grep -q 'kea_dhcpv6_config' "$KEA_DHCPV6" 2>/dev/null || echo "  - $KEA_DHCPV6"
        exit 1
    fi
fi

# --- Step 2: Install plugin files ---
echo "==> Installing kea-ddns plugin files..."
PLUGIN_SRC="$REPO_DIR/net/kea-ddns/src"
cp -R "$PLUGIN_SRC/etc/inc/plugins.inc.d/kea_ddns.inc" "$CORE_SRC/etc/inc/plugins.inc.d/"
mkdir -p "$CORE_SRC/opnsense/data/kea-ddns/patches"
cp -R "$PLUGIN_SRC/opnsense/data/kea-ddns/patches/"* "$CORE_SRC/opnsense/data/kea-ddns/patches/"
cp -R "$PLUGIN_SRC/opnsense/mvc/app/controllers/OPNsense/KeaDdns" "$CORE_SRC/opnsense/mvc/app/controllers/OPNsense/"
cp -R "$PLUGIN_SRC/opnsense/mvc/app/models/OPNsense/KeaDdns" "$CORE_SRC/opnsense/mvc/app/models/OPNsense/"
cp -R "$PLUGIN_SRC/opnsense/mvc/app/views/OPNsense/KeaDdns" "$CORE_SRC/opnsense/mvc/app/views/OPNsense/"
cp "$PLUGIN_SRC/opnsense/service/templates/OPNsense/Syslog/local/keaddns.conf" "$CORE_SRC/opnsense/service/templates/OPNsense/Syslog/local/"
echo "    Plugin files installed."

# --- Step 3: Flush cache and restart ---
echo "==> Flushing config cache..."
configctl template reload OPNsense/Syslog 2>/dev/null || true
/usr/local/etc/rc.configure_firmware 2>/dev/null || true

echo ""
echo "==> Done! Navigate to Services > Kea DDNS in the web UI."
echo "    Run 'configctl kea restart' to apply changes."

# --- Step 4: Run functional tests ---
echo ""
echo "==> Running functional tests..."
echo ""
sh "$SCRIPT_DIR/functional_test.sh"
