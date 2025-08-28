#!/usr/bin/env bash
set -euo pipefail
SDK_DIR=${1:? "usage: $0 <sdk-dir> <arch>"}
ARCH=${2:-x86_64}
PKG_SRC_DIR=$(cd "$(dirname "$0")/.."; pwd)/package/rvi-probe
cd "$SDK_DIR"; ./scripts/feeds update -a && ./scripts/feeds install -a
mkdir -p package/utils/rvi-probe; rsync -a --delete "$PKG_SRC_DIR"/ package/utils/rvi-probe/
make defconfig; make package/rvi-probe/compile V=s
echo "Built packages in: $(pwd)/bin/packages"
