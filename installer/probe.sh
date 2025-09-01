#!/usr/bin/env bash
set -euo pipefail
log(){ echo "[rvi-probe] $*"; }
OS="$(uname -s)"; ID=""; SUDO=""; command -v sudo >/dev/null 2>&1 && SUDO="sudo"

RV_FEED_URL="${RV_FEED_URL:-https://r2.rvinternethelp.com/openwrt/23.05}"
RV_WORKER_URL="${RV_WORKER_URL:-https://status-hunter.traveldata.workers.dev/}"
PKG_VERSION="${PKG_VERSION:-0.5.0}"
PKG_RELEASE="${PKG_RELEASE:-8}"
CF_FEED_URL="${CF_FEED_URL:-https://r2.rvinternethelp.com/cloudflared}"
CF_VERSION="${CF_VERSION:-2024.6.0}"
CF_RELEASE="${CF_RELEASE:-1}"

is_openwrt(){ [ -f /etc/openwrt_release ] || command -v opkg >/dev/null 2>&1; }
lsb(){ [ -f /etc/os-release ] && . /etc/os-release; ID="${ID:-}"; }

verify_openwrt_services(){
  metrics=$(awk '/^ *metrics:/{print $2}' /etc/cloudflared/config.yml 2>/dev/null | tail -n1)
  metrics=${metrics:-127.0.0.1:2000}
  uhttpd=$(uci get uhttpd.rvi.listen_http 2>/dev/null || true)
  uhttpd=${uhttpd:-127.0.0.1:8081}
  sleep 5
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$metrics/ready" || true)
  [ "$status" -eq 200 ] || { log "cloudflared not ready at $metrics (status $status)"; exit 1; }
  resp=$(curl -fsS --max-time 5 "http://$uhttpd/json" 2>/dev/null) || {
    log "probe HTTP check failed at $uhttpd"; exit 1; }
  if command -v jq >/dev/null 2>&1; then
    echo "$resp" | jq empty >/dev/null || { log "invalid JSON from probe"; exit 1; }
  else
    echo "$resp" | grep -q '{' || { log "invalid JSON from probe"; exit 1; }
  fi
}

install_openwrt(){
  log "Detected OpenWrt/FriendlyWrt"
  $SUDO opkg update || true
  if ! grep -q "rvi_r2" /etc/opkg/customfeeds.conf 2>/dev/null; then
    ARCH=$(opkg print-architecture | tail -n1 | awk '{print $2}')
    echo "src/gz rvi_r2 ${RV_FEED_URL}/${ARCH}" | $SUDO tee -a /etc/opkg/customfeeds.conf
  fi
  if ! grep -q '^src/gz luci ' /etc/opkg/customfeeds.conf 2>/dev/null; then
    DIST=$(. /etc/openwrt_release; echo $DISTRIB_RELEASE)
    ARCH=$(opkg print-architecture | tail -n1 | awk '{print $2}')
    echo "src/gz luci https://downloads.openwrt.org/releases/${DIST}/packages/${ARCH}/luci" | $SUDO tee -a /etc/opkg/customfeeds.conf
  fi
  $SUDO opkg update
  $SUDO opkg install ca-bundle ca-certificates curl jq || true
  $SUDO opkg install rvi-probe || {
    log "Falling back to direct ipk download"; ARCH=$(opkg print-architecture | tail -n1 | awk '{print $2}')
    TMP=$(mktemp); URL="${RV_FEED_URL}/${ARCH}/rvi-probe_${PKG_VERSION}-${PKG_RELEASE}_${ARCH}.ipk"
    curl -fsSL "$URL" -o "$TMP"; $SUDO opkg install "$TMP" && rm -f "$TMP"
  } 
  $SUDO opkg install cloudflared || {
    log "Falling back to direct cloudflared ipk download"
    ARCH=$(opkg print-architecture | tail -n1 | awk '{print $2}')
    TMP=$(mktemp)
    URL="${CF_FEED_URL}/${ARCH}/cloudflared_${CF_VERSION}-${CF_RELEASE}_${ARCH}.ipk"
    curl -fsSL "$URL" -o "$TMP"
    $SUDO opkg install "$TMP" && rm -f "$TMP"
  }
  $SUDO /etc/init.d/cloudflared enable
  $SUDO /etc/init.d/cloudflared start
  $SUDO uci set rviprobe.config.worker_url="$RV_WORKER_URL" || true
  $SUDO uci commit rviprobe || true
  $SUDO /etc/init.d/rvi-probe enable || true
  $SUDO /etc/init.d/rvi-probe start || true
  $SUDO rvi-cloudflared-check >/dev/null || { log "rvi-cloudflared-check failed after start"; exit 1; }
  verify_openwrt_services
  log "OpenWrt install complete"
}

install_debian(){
  $SUDO apt-get update -y
  $SUDO apt-get install -y curl ca-certificates jq iproute2 iputils-ping cron
  mkdir -p "$HOME/.rvi-probe"
  cat > "$HOME/.rvi-probe/agent.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKER_URL="${RV_WORKER_URL:-https://status-hunter.traveldata.workers.dev/}"
interval="${RV_INTERVAL:-300}"
log(){ logger -t rvi-probe "$*" || echo "$*"; }
while true; do
  IF=$(ip -4 route show default | awk '{print $5; exit}')
  IP=$(ip -4 addr show "$IF" | awk '/inet /{print $2; exit}')
  RTT=$(ping -c1 -W1 1.1.1.1 2>/dev/null | awk -F'/' '/rtt/{print $5}')
  DATA=$(printf '{"host":"%s","if":"%s","ip":"%s","rtt_ms":"%s"}' "$(hostname)" "$IF" "$IP" "$RTT")
  curl -fsS -H 'Content-Type: application/json' -d "$DATA" "$WORKER_URL" >/dev/null || true
  sleep "$interval"
done
SH
  chmod +x "$HOME/.rvi-probe/agent.sh"
  $SUDO tee /etc/systemd/system/rvi-probe.service >/dev/null <<SERVICE
[Unit]
Description=RVInternetHelp Probe
After=network-online.target
Wants=network-online.target
[Service]
Environment=RV_WORKER_URL=${RV_WORKER_URL}
ExecStart=$HOME/.rvi-probe/agent.sh
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
SERVICE
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now rvi-probe
  log "Debian/Ubuntu install complete"
}

install_alpine(){
  $SUDO apk add --no-cache curl ca-certificates jq iproute2 iputils
  install_debian
}

main(){
  if is_openwrt; then install_openwrt; return; fi
  lsb
  case "$ID" in
    ubuntu|debian) install_debian ;;
    alpine) install_alpine ;;
    *) log "Unsupported distro; manual install required" ; exit 1 ;;
  esac
}
main "$@"
