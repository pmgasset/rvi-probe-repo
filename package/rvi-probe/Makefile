include $(TOPDIR)/rules.mk

PKG_NAME:=rvi-probe
PKG_VERSION:=0.5.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/rvi-probe
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=RVInternetHelp Network Probe
  DEPENDS:=+curl +ca-bundle +ca-certificates +jq +busybox +coreutils +coreutils-base64 +ip-full +procps-ng-ps +ubus +uclient-fetch +iwinfo +wireless-tools +openssl-util
endef

define Package/rvi-probe/description
Support/diagnostics agent with outage checks, speed tests, Cloudflare tunnel share code, JSON status, cell metrics, and CRM hooks.
endef

define Build/Compile
endef

define Package/rvi-probe/install
	$(CP) ./files/* $(1)/
	chmod 0755 $(1)/etc/init.d/rvi-probe
	chmod 0755 $(1)/usr/bin/rvi-*
	chmod 0755 $(1)/usr/lib/rvi-probe/agent.sh
	chmod 0755 $(1)/usr/lib/rvi-probe/cell.sh
	chmod 0755 $(1)/www/cgi-bin/supportlink
	chmod 0755 $(1)/www/cgi-bin/json
endef

$(eval $(call BuildPackage,rvi-probe))
