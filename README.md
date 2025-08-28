# RVInternetHelp rvi-probe

OpenWrt/FriendlyWrt probe package + universal installer.

- **Option B** isolation: SupportLink served via a separate uHTTPd on loopback (127.0.0.1:8081).
- Prefers **librespeed-cli**, falls back to Ookla CLI, then to curl probe.
- Cell metrics via `uqmi` or `mmcli`.
- JSON status at `/json` for dashboards.
- Feed signing via `usign` (optional).

## Quick start (local build)
1. Download the OpenWrt SDK matching your target (ath79 for GL.iNet X750; ipq40xx/mediatek for others).
2. Copy `package/rvi-probe` into `openwrt-sdk/package/utils/`.
3. Run `scripts/build-openwrt.sh <sdk-dir> <arch>` (see workflow for supported arches).
4. Run `scripts/mk-packages-index.sh <sdk-dir>/bin/packages`.
5. Run `scripts/publish-r2.sh <sdk-dir>/bin/packages`.

## Installer
Host `installer/probe.sh` at `https://install.rvinternethelp.com/probe.sh`.
Default worker URL: `https://status-hunter.traveldata.workers.dev/`.

## Cloudflared (Option B)
- `uhttpd/rvi.conf` adds a second HTTP listener on 127.0.0.1:8081 for SupportLink.
- `cloudflared/config.yml.example` points the tunnel to 127.0.0.1:8081.

## Signing
Generate usign keys offline and add the base64 private key to GitHub secrets.
Devices must have the public key under `/etc/opkg/keys/` to trust the feed.

## License
MIT
