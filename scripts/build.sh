#!/bin/sh
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGINS_REPO="https://github.com/opnsense/plugins.git"
PLUGINS_DIR="${REPO_ROOT}/../opnsense-plugins"

echo "==> opnsense-kea-ddns package builder"

# Clone opnsense/plugins if not present (sparse checkout for build infra only)
if [ ! -d "$PLUGINS_DIR" ]; then
    echo "==> Cloning opnsense/plugins (sparse checkout)..."
    git clone --depth 1 --filter=blob:none --sparse "$PLUGINS_REPO" "$PLUGINS_DIR"
    cd "$PLUGINS_DIR"
    git sparse-checkout set Mk Keywords Templates Scripts
    cd "$REPO_ROOT"
else
    echo "==> Using existing opnsense/plugins at $PLUGINS_DIR"
fi

# Create symlinks for build infrastructure
for dir in Mk Keywords Templates Scripts; do
    target="$REPO_ROOT/$dir"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        echo "ERROR: $target exists and is not a symlink. Remove it first."
        exit 1
    fi
    ln -s "$PLUGINS_DIR/$dir" "$target"
    echo "    $dir -> $PLUGINS_DIR/$dir"
done

# Build the package
echo "==> Building package..."
cd "$REPO_ROOT/net/kea-ddns"
make package

echo ""
echo "==> Build complete. Package:"
ls -la work/pkg/*.pkg 2>/dev/null || echo "ERROR: No package found in work/pkg/"
