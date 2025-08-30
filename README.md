# RVInternetHelp rvi-probe

OpenWrt/FriendlyWrt probe package + universal installer.

- **Option B** isolation: SupportLink via uHTTPd on 127.0.0.1:8081
- Prefers **librespeed-cli**, falls back to Ookla CLI, then curl probe
- Cell metrics via `uqmi`/`mmcli`
- JSON status at `/json`
- Optional feed signing via `usign`

## Quick start (local build)
1. Download the OpenWrt SDK matching any target (we build `noarch`): e.g. x86_64 SDK 23.05.3.

2. Copy `package/rvi-probe` into `openwrt-sdk/package/utils/`.

3. Run `scripts/build-openwrt.sh <sdk-dir> x86_64`.

4. Run `scripts/mk-packages-index.sh <sdk-dir>/bin/packages`.

5. Run `scripts/publish-r2.sh <sdk-dir>/bin/packages`.


Default Worker URL: `https://status-hunter.traveldata.workers.dev/`.

## Package verification

Unpack and inspect the IPK locally:

```
ar t rvi-probe_0.5.0-2_all.ipk
ar x rvi-probe_0.5.0-2_all.ipk
tar -tzf data.tar.gz
```

On device:

```
opkg update
opkg install rvi-probe
opkg files rvi-probe
ls -l /etc/init.d/rvi-probe /usr/bin/rvi-probe.sh /www/cgi-bin/supportlink
/etc/init.d/rvi-probe start
```
###
