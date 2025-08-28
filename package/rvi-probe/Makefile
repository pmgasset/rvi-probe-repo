include $(TOPDIR)/rules.mk

PKG_NAME:=rvi-probe
PKG_VERSION:=0.5.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/rvi-probe
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=RVInternetHelp Network Probe
  DEPENDS:=+curl +ca-bundle +ca-certificates +jq +ip-full +ubus +uclient-fetch +iwinfo +wireless-tools +openssl-util
endef

define Package/rvi-probe/description
Support/diagnostics agent with outage checks, speed tests, Cloudflare tunnel share code, JSON status, cell metrics, and CRM hooks.
endef

define Build/Compile
endef

define Package/rvi-probe/install
        $(INSTALL_DIR) $(1)/etc/init.d
        $(INSTALL_BIN) ./files/etc/init.d/rvi-probe $(1)/etc/init.d/rvi-probe

        $(INSTALL_DIR) $(1)/etc/uci-defaults
        $(INSTALL_DATA) ./files/etc/uci-defaults/99-rvi-probe $(1)/etc/uci-defaults/99-rvi-probe

        $(INSTALL_DIR) $(1)/etc/config
        $(INSTALL_CONF) ./files/etc/config/rviprobe $(1)/etc/config/rviprobe

        $(INSTALL_DIR) $(1)/usr/bin
        $(INSTALL_BIN) ./files/usr/bin/rvi-outage-check $(1)/usr/bin/rvi-outage-check
        $(INSTALL_BIN) ./files/usr/bin/rvi-sharecode $(1)/usr/bin/rvi-sharecode
        $(INSTALL_BIN) ./files/usr/bin/rvi-speedtest $(1)/usr/bin/rvi-speedtest

        $(INSTALL_DIR) $(1)/usr/lib/rvi-probe
        $(INSTALL_BIN) ./files/usr/lib/rvi-probe/agent.sh $(1)/usr/lib/rvi-probe/agent.sh
        $(INSTALL_BIN) ./files/usr/lib/rvi-probe/cell.sh $(1)/usr/lib/rvi-probe/cell.sh

        $(INSTALL_DIR) $(1)/www/cgi-bin
        $(INSTALL_BIN) ./files/www/cgi-bin/supportlink $(1)/www/cgi-bin/supportlink
        $(INSTALL_BIN) ./files/www/cgi-bin/json $(1)/www/cgi-bin/json
endef

$(eval $(call BuildPackage,rvi-probe))
