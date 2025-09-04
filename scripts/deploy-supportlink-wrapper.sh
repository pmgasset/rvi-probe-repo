#!/bin/sh
set -e

SRC_DIR=$(dirname "$0")
WRAPPER="$SRC_DIR/supportlink-wrapper"
TARGET=/www/cgi-bin/supportlink
BACKUP=/www/cgi-bin/supportlink.api

if [ ! -f "$BACKUP" ] && [ -f "$TARGET" ]; then
  mv "$TARGET" "$BACKUP"
fi

cp "$WRAPPER" "$TARGET"
chmod +x "$TARGET"

/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

# Verification
printf 'HTML check: '
curl -fsS http://localhost/cgi-bin/supportlink | head -n 1 || true
printf '\nJSON check: '
curl -fsS -H 'Accept: application/json' http://localhost/cgi-bin/supportlink | head -n 1 || true
