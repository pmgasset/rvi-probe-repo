#!/usr/bin/env bash
set -euo pipefail

SDK_DIR=${1:? "usage: $0 <sdk-dir> <arch>"}
ARCH=${2:-x86_64}

# Locate source dir and parse package version
PKG_SRC_DIR=$(cd "$(dirname "$0")/.."; pwd)/package/rvi-probe
PKG_VERSION=$(grep '^PKG_VERSION:=' "$PKG_SRC_DIR/Makefile" | cut -d '=' -f2 | tr -d ' \t')
PKG_RELEASE=$(grep '^PKG_RELEASE:=' "$PKG_SRC_DIR/Makefile" | cut -d '=' -f2 | tr -d ' \t')
PKG_VER="${PKG_VERSION}-${PKG_RELEASE}"

cd "$SDK_DIR"; ./scripts/feeds update -a && ./scripts/feeds install -a

# Copy package sources into SDK and stamp the postinst with the version
mkdir -p package/utils/rvi-probe
rsync -a --delete "$PKG_SRC_DIR"/ package/utils/rvi-probe/
sed -i "s/__VER__/${PKG_VER}/g" package/utils/rvi-probe/files/CONTROL/postinst

make defconfig; make package/rvi-probe/compile V=s
echo "Built packages in: $(pwd)/bin/packages"
