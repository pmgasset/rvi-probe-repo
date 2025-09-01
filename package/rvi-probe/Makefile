include $(TOPDIR)/rules.mk

PKG_NAME:=rvi-probe
PKG_VERSION:=0.5.0
PKG_RELEASE:=8
PKG_LICENSE:=MIT
PKG_MAINTAINER:=RVInternetHelp <support@rvinternethelp.com>
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/rvi-probe
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Monitoring
  TITLE:=RVInternetHelp Network Probe
  DEPENDS:=+curl +ca-bundle +ca-certificates +jq +ip-full +ubus +uclient-fetch +iwinfo +wireless-tools +openssl-util +cloudflared
  # If you want uhttpd to be auto-installed too, uncomment:
  # DEPENDS+= +uhttpd
endef

define Package/rvi-probe/description
Support/diagnostics agent with outage checks, speed tests, Cloudflare tunnel share code,
JSON status, cell metrics, and CRM hooks.
endef

# Persist any local state you place under /etc/rvi-probe
define Package/rvi-probe/conffiles
/etc/rvi-probe
endef

define Build/Compile
  # nothing to compile
endef

# ===== File install (matches repo paths under package/rvi-probe/files) =====
define Package/rvi-probe/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/rvi-probe $(1)/etc/init.d/rvi-probe

        $(INSTALL_DIR) $(1)/usr/bin
        $(INSTALL_BIN) ./files/usr/bin/rvi-probe     $(1)/usr/bin/rvi-probe
        $(INSTALL_BIN) ./files/usr/bin/rvi-speedtest $(1)/usr/bin/rvi-speedtest
        $(INSTALL_BIN) ./files/usr/bin/rvi-sharecode $(1)/usr/bin/rvi-sharecode
        $(INSTALL_BIN) ./files/usr/bin/rvi-cloudflared-check $(1)/usr/bin/rvi-cloudflared-check

	$(INSTALL_DIR) $(1)/usr/lib/rvi-probe
	$(INSTALL_BIN) ./files/usr/lib/rvi-probe/agent.sh $(1)/usr/lib/rvi-probe/agent.sh
	$(INSTALL_BIN) ./files/usr/lib/rvi-probe/cell.sh  $(1)/usr/lib/rvi-probe/cell.sh

	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) ./files/www/cgi-bin/supportlink $(1)/www/cgi-bin/supportlink
	$(INSTALL_BIN) ./files/www/cgi-bin/json        $(1)/www/cgi-bin/json

	$(INSTALL_DIR) $(1)/etc/rvi-probe
endef

# ===== Maintainer scripts =====
define Package/rvi-probe/preinst
#!/bin/sh
# Keep preinst a no-op; do NOT 'set -e'
exit 0
endef

define Package/rvi-probe/postinst
#!/bin/sh
# opkg runs: postinst <pkgver> configure
# Make everything non-fatal to avoid rollback-to-empty issues.
set +e

log() { echo "[rvi-probe postinst] $$*"; }
have() { command -v "$$1" >/dev/null 2>&1; }

MARK_DIR="/etc/rvi-probe"
UHTTPD_MARK="$$MARK_DIR/uhttpd_installed"
CF_MARK="$$MARK_DIR/cloudflared_configured"
mkdir -p "$$MARK_DIR" 2>/dev/null

safe_chmod() {
  for f in "$$@"; do
    [ -e "$$f" ] && chmod 0755 "$$f" 2>/dev/null
  done
}

add_uhttpd() {
  if ! have uci; then
    log "uci not found; skipping uhttpd config"
    return 0
  fi
  [ -f /etc/config/uhttpd ] || touch /etc/config/uhttpd

  if ! uci -q get uhttpd.rvi >/dev/null 2>&1; then
    uci -q batch <<'EOF'
set uhttpd.rvi=uhttpd
set uhttpd.rvi.listen_http='127.0.0.1:8081'
set uhttpd.rvi.home='/www'
add_list uhttpd.rvi.cgi_prefix='/cgi-bin'
set uhttpd.rvi.script_timeout='60'
set uhttpd.rvi.network_timeout='30'
set uhttpd.rvi.tcp_keepalive='1'
add_list uhttpd.rvi.alias='/json=/cgi-bin/json'
commit uhttpd
EOF
    touch "$$UHTTPD_MARK"
    log "Configured uhttpd.rvi"
  else
    uci -q add_list uhttpd.rvi.alias='/json=/cgi-bin/json' 2>/dev/null
    uci -q commit uhttpd
    log "Updated uhttpd.rvi alias"
  fi

  [ -x /etc/init.d/uhttpd ] && { /etc/init.d/uhttpd reload >/dev/null 2>&1 || /etc/init.d/uhttpd restart >/dev/null 2>&1 || true; }
}

setup_cloudflared() {
  [ -x /etc/init.d/cloudflared ] || { log "cloudflared not present; skipping"; return 0; }
  CFG=/etc/cloudflared/config.yml
  mkdir -p /etc/cloudflared 2>/dev/null
  if [ ! -s "$$CFG" ] || ! grep -q "127.0.0.1:8081" "$$CFG" 2>/dev/null; then
    cat > "$$CFG" <<'YAML'
url: http://127.0.0.1:8081
metrics: 127.0.0.1:2000
ingress:
  - service: http://127.0.0.1:8081
  - service: http_status:404
YAML
    touch "$$CF_MARK"
    log "Wrote $$CFG"
  fi
  /etc/init.d/cloudflared enable >/dev/null 2>&1 || true
  /etc/init.d/cloudflared restart >/dev/null 2>&1 || true
}

# Ensure modes (if files unpacked)
safe_chmod \
  /usr/bin/rvi-* \
  /usr/lib/rvi-probe/agent.sh \
  /usr/lib/rvi-probe/cell.sh \
  /www/cgi-bin/supportlink \
  /www/cgi-bin/json

# Enable/start our service if present
if [ -x /etc/init.d/rvi-probe ]; then
  /etc/init.d/rvi-probe enable >/dev/null 2>&1 || true
  /etc/init.d/rvi-probe start  >/dev/null 2>&1 || true
fi

add_uhttpd
setup_cloudflared

log "postinst complete"
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
