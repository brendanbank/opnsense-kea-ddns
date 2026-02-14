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

# Check if hooks are already present
if grep -q 'kea_ddns_generate' "$KEA_INC" 2>/dev/null; then
    echo "    Core hooks already applied, skipping patch."
else
    echo "==> Applying core hooks patch..."
    # Apply the patch relative to the src/ prefix used in core
    cd "$CORE_SRC"
    patch --forward --strip=1 --dry-run < "$PATCH_FILE" || {
        echo "ERROR: Patch does not apply cleanly to this OPNsense version."
        echo "You may need to apply the patch manually."
        echo "Files to patch:"
        echo "  - $KEA_INC"
        echo "  - $KEA_DHCPV4"
        exit 1
    }
    patch --forward --strip=1 < "$PATCH_FILE"
    echo "    Core hooks applied successfully."
fi

# --- Step 2: Install plugin files ---
echo "==> Installing kea-ddns plugin files..."
PLUGIN_SRC="$REPO_DIR/net/kea-ddns/src"
cp -R "$PLUGIN_SRC/etc/inc/plugins.inc.d/kea_ddns.inc" "$CORE_SRC/etc/inc/plugins.inc.d/"
cp -R "$PLUGIN_SRC/opnsense/mvc/app/controllers/OPNsense/KeaDdns" "$CORE_SRC/opnsense/mvc/app/controllers/OPNsense/"
cp -R "$PLUGIN_SRC/opnsense/mvc/app/models/OPNsense/KeaDdns" "$CORE_SRC/opnsense/mvc/app/models/OPNsense/"
cp -R "$PLUGIN_SRC/opnsense/mvc/app/views/OPNsense/KeaDdns" "$CORE_SRC/opnsense/mvc/app/views/OPNsense/"
echo "    Plugin files installed."

# --- Step 3: Flush cache and restart ---
echo "==> Flushing config cache..."
configctl template reload OPNsense/Syslog 2>/dev/null || true
/usr/local/etc/rc.configure_firmware 2>/dev/null || true

echo ""
echo "==> Done! Navigate to Services > Kea DDNS in the web UI."
echo "    Run 'configctl kea restart' to apply changes."
