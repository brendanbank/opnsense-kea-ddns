#!/bin/sh

# Uninstall script for opnsense-kea-ddns
# Removes plugin files and reverses the core patch.

set -e

SCRIPT_DIR=$(dirname "$(realpath "$0")")
REPO_DIR=$(dirname "$SCRIPT_DIR")

CORE_SRC="/usr/local"
PATCH_FILE="$REPO_DIR/core-patches/0001-kea-add-plugins_run-hooks-for-DDNS-plugin-support.patch"

echo "==> opnsense-kea-ddns uninstaller"
echo ""

# --- Step 1: Remove plugin files ---
echo "==> Removing kea-ddns plugin files..."
rm -f "$CORE_SRC/etc/inc/plugins.inc.d/kea_ddns.inc"
rm -rf "$CORE_SRC/opnsense/mvc/app/controllers/OPNsense/KeaDdns"
rm -rf "$CORE_SRC/opnsense/mvc/app/models/OPNsense/KeaDdns"
rm -rf "$CORE_SRC/opnsense/mvc/app/views/OPNsense/KeaDdns"
echo "    Plugin files removed."

# --- Step 2: Reverse core patch ---
echo "==> Reversing core hooks patch..."
cd "$CORE_SRC"
if patch --reverse --strip=1 --dry-run < "$PATCH_FILE" 2>/dev/null; then
    patch --reverse --strip=1 < "$PATCH_FILE"
    echo "    Core hooks removed."
else
    echo "    Core patch could not be reversed cleanly (may already be removed or OPNsense was updated)."
    echo "    You may need to manually check:"
    echo "      - $CORE_SRC/etc/inc/plugins.inc.d/kea.inc"
    echo "      - $CORE_SRC/opnsense/mvc/app/models/OPNsense/Kea/KeaDhcpv4.php"
fi

# --- Step 3: Restart ---
echo "==> Restarting Kea..."
configctl kea restart 2>/dev/null || true

echo ""
echo "==> Done! kea-ddns has been removed."
