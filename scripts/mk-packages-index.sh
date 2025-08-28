#!/usr/bin/env bash
set -euo pipefail
OUT=${1:-bin/packages}
cd "$OUT"
opkg-make-index . > Packages && gzip -fk9 Packages
ls -l Packages Packages.gz
