#!/usr/bin/env bash
set -euo pipefail
SDK_DIR=${1:? "usage: $0 <sdk-dir> <arch>"}
ARCH=${2:-x86_64}
PKG_SRC_DIR=$(cd "$(dirname "$0")/.."; pwd)/package/rvi-probe
cd "$SDK_DIR"; ./scripts/feeds update -a && ./scripts/feeds install -a
mkdir -p package/utils/rvi-probe; rsync -a --delete "$PKG_SRC_DIR"/ package/utils/rvi-probe/
make defconfig
make package/rvi-probe/compile V=s CONFIG_TARGET_IPK_FORMAT=gzip
PKG_FILE=$(find bin/packages -name 'rvi-probe_*.ipk' | head -n1)
if [[ -z "$PKG_FILE" ]]; then
  echo "rvi-probe ipk not found" >&2
  exit 1
fi
CONTENTS=$(ar -t "$PKG_FILE")
for part in debian-binary control.tar.gz data.tar.gz; do
  if ! grep -qx "$part" <<<"$CONTENTS"; then
    echo "missing $part in $PKG_FILE" >&2
    exit 1
  fi
done
ar -p "$PKG_FILE" control.tar.gz | tar -tzf - >/dev/null
ar -p "$PKG_FILE" data.tar.gz | tar -tzf - >/dev/null
echo "Built package: $PKG_FILE"
