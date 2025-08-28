#!/bin/sh
set -eu
if command -v uqmi >/dev/null 2>&1; then
  DEV=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1 || true)
  [ -n "$DEV" ] || { echo "No cdc-wdm modem found"; exit 0; }
  echo "Backend: uqmi ($DEV)"
  echo "== Signal =="; uqmi -d "$DEV" --get-signal-info 2>/dev/null || true
  echo "== Serving System =="; uqmi -d "$DEV" --get-serving-system 2>/dev/null || true
  echo "== Cell Info =="; uqmi -d "$DEV" --get-cell-info 2>/dev/null || true
  exit 0
fi
if command -v mmcli >/dev/null 2>&1; then
  echo "Backend: mmcli"
  mmcli -m 0 --signal 2>/dev/null || true
  mmcli -m 0 2>/dev/null || true
  exit 0
fi
echo "No cellular backend available (uqmi/mmcli)"
