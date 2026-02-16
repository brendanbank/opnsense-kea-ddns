#!/bin/sh
#
# Build an OPNsense plugin package (.pkg) for os-kea-ddns.
#
# Usage: ./scripts/build.sh <hostname>
#
# The build happens on a FreeBSD/OPNsense host via SSH. Build infrastructure
# (Mk/, Keywords/, etc.) is obtained via a sparse checkout of opnsense/plugins.
# Local source is synced to the remote repo before building.
#
# After building, the script tests both the upgrade and fresh-install paths,
# verifying that core patches are correctly applied and reversed.
#

set -e

FIREWALL="${1:-${FIREWALL:?Usage: ./scripts/build.sh <hostname>}}"
REMOTE_REPO="/home/brendan/src/opnsense-kea-ddns"
REMOTE_PLUGINS="/home/brendan/src/opnsense-plugins"
REMOTE_PLUGIN_DIR="${REMOTE_REPO}/net/kea-ddns"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_DIST="${REPO_ROOT}/dist"

KEA_INC="/usr/local/etc/inc/plugins.inc.d/kea.inc"
KEA_DDNS_INC="/usr/local/etc/inc/plugins.inc.d/kea_ddns.inc"

# ── helpers ──────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

remote() { ssh "${FIREWALL}" "$@"; }

verify_installed() {
    echo "    Checking core patch applied..."
    remote "grep -q 'kea_ddns_generate' ${KEA_INC}" \
        || die "Core patch NOT applied after $1"
    echo "    Checking plugin file installed..."
    remote "test -f ${KEA_DDNS_INC}" \
        || die "Plugin file ${KEA_DDNS_INC} missing after $1"
    echo "    Checking package registered..."
    remote "pkg info os-kea-ddns >/dev/null 2>&1" \
        || die "Package os-kea-ddns not registered after $1"
    echo "    OK"
}

verify_removed() {
    echo "    Checking core patch reversed..."
    remote "! grep -q 'kea_ddns_generate' ${KEA_INC}" \
        || die "Core patch still applied after remove"
    echo "    Checking plugin file removed..."
    remote "! test -f ${KEA_DDNS_INC}" \
        || die "Plugin file ${KEA_DDNS_INC} still present after remove"
    echo "    OK"
}

# ── 1. Sync source to remote ────────────────────────────────────────

echo "==> Building on ${FIREWALL}"

echo "==> Syncing local source to ${FIREWALL}"
remote "rm -rf ${REMOTE_PLUGIN_DIR}/src && mkdir -p ${REMOTE_PLUGIN_DIR}
    if [ ! -d ${REMOTE_REPO}/.git ]; then
        git -C ${REMOTE_REPO} init -q
        git -C ${REMOTE_REPO} commit --allow-empty -q -m init
    fi
"
scp -q "${REPO_ROOT}/net/kea-ddns/Makefile" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"
scp -q "${REPO_ROOT}/net/kea-ddns/pkg-descr" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"
scp -rq "${REPO_ROOT}/net/kea-ddns/src" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"
for hook in +POST_INSTALL.post +PRE_DEINSTALL.pre +PRE_INSTALL.pre; do
    if [ -f "${REPO_ROOT}/net/kea-ddns/${hook}" ]; then
        scp -q "${REPO_ROOT}/net/kea-ddns/${hook}" "${FIREWALL}:${REMOTE_PLUGIN_DIR}/"
    fi
done

# ── 2. Ensure build infrastructure ──────────────────────────────────

echo "==> Checking for plugins build infrastructure"
remote "
    if [ ! -d ${REMOTE_PLUGINS}/.git ]; then
        echo '    Cloning opnsense/plugins (sparse checkout)...'
        git clone --depth 1 --filter=blob:none --sparse \
            https://github.com/opnsense/plugins.git ${REMOTE_PLUGINS}
        cd ${REMOTE_PLUGINS} && git sparse-checkout set Mk Keywords Templates Scripts
    fi
"

# ── 3. Build ─────────────────────────────────────────────────────────

echo "==> Creating build symlinks"
remote "
    cd ${REMOTE_REPO}
    for dir in Mk Keywords Templates Scripts; do
        ln -sfn ${REMOTE_PLUGINS}/\$dir \$dir
    done
    : > ${REMOTE_PLUGINS}/Mk/devel.mk
"

echo "==> Cleaning previous build"
remote "sudo rm -rf ${REMOTE_PLUGIN_DIR}/work"

echo "==> Running make package"
remote "cd ${REMOTE_PLUGIN_DIR} && make package"

# Find the built .pkg
PKG_PATH=$(remote "ls -1 ${REMOTE_PLUGIN_DIR}/work/pkg/*.pkg 2>/dev/null | head -1")
[ -n "${PKG_PATH}" ] || die "No .pkg file found on remote"
PKG_NAME=$(basename "${PKG_PATH}")
echo "==> Built: ${PKG_NAME}"

# ── 4. Test upgrade path ─────────────────────────────────────────────

echo ""
echo "==> Testing UPGRADE path"
remote "sudo pkg install -fy ${PKG_PATH}"
verify_installed "upgrade install"

# ── 5. Test fresh install path ────────────────────────────────────────

echo ""
echo "==> Testing FRESH INSTALL path"
echo "    Removing package..."
remote "sudo pkg remove -y os-kea-ddns"
verify_removed

echo "    Installing from scratch..."
remote "sudo pkg install -fy ${PKG_PATH}"
verify_installed "fresh install"

# ── 6. Download .pkg locally ─────────────────────────────────────────

echo ""
echo "==> Downloading package to ${LOCAL_DIST}/"
mkdir -p "${LOCAL_DIST}"
scp -q "${FIREWALL}:${PKG_PATH}" "${LOCAL_DIST}/"
echo "    ${LOCAL_DIST}/${PKG_NAME}"

# ── 7. Update GitHub Pages repo ──────────────────────────────────────

PAGES_REPO="${REPO_ROOT}/docs/repo"
if [ -d "${PAGES_REPO}" ]; then
    echo "==> Updating GitHub Pages pkg repo"
    REMOTE_REPO_DIR="/tmp/kea_ddns_repo"
    remote "rm -rf ${REMOTE_REPO_DIR} && mkdir -p ${REMOTE_REPO_DIR}"
    scp -q "${LOCAL_DIST}/${PKG_NAME}" "${FIREWALL}:${REMOTE_REPO_DIR}/"
    remote "pkg repo ${REMOTE_REPO_DIR}/"
    rm -f "${PAGES_REPO}"/os-kea-ddns*.pkg
    rm -f "${PAGES_REPO}"/{meta.conf,packagesite.*,data.*,filesite.*}
    scp -q "${FIREWALL}:${REMOTE_REPO_DIR}/*" "${PAGES_REPO}/"
    remote "rm -rf ${REMOTE_REPO_DIR}"
    echo "    Commit and push docs/ to update GitHub Pages."
fi

# ── 8. Clean up ───────────────────────────────────────────────────────

echo "==> Cleaning build artifacts"
remote "sudo rm -rf ${REMOTE_PLUGIN_DIR}/work"

echo "==> Done"
