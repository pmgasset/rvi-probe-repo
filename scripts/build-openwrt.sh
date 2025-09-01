#!/usr/bin/env bash
set -euo pipefail
SDK_DIR=${1:? "usage: $0 <sdk-dir> <arch>"}
ARCH=${2:-x86_64}
PKG_SRC_DIR=$(cd "$(dirname "$0")/.."; pwd)/package/rvi-probe

cd "$SDK_DIR"; ./scripts/feeds update -a && ./scripts/feeds install -a

mkdir -p package/utils/rvi-probe
rsync -a --delete "$PKG_SRC_DIR"/ package/utils/rvi-probe/

# Insert the package version into the post-install script so that the
# generated IPK contains a URL pointing to the correct installer payload.
PKG_VERSION=$(grep -m1 '^PKG_VERSION:=' "$PKG_SRC_DIR/Makefile" | cut -d= -f2 | tr -d ' \t')
PKG_RELEASE=$(grep -m1 '^PKG_RELEASE:=' "$PKG_SRC_DIR/Makefile" | cut -d= -f2 | tr -d ' \t')
POSTINST=package/utils/rvi-probe/files/CONTROL/postinst
sed -e "s/__VER__/${PKG_VERSION}-${PKG_RELEASE}/" "$POSTINST" > "${POSTINST}.tmp"
mv "${POSTINST}.tmp" "$POSTINST"

make defconfig
make package/rvi-probe/compile V=s
echo "Built packages in: $(pwd)/bin/packages"
