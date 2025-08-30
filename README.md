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

## Cloudflare provisioning (per-device hostname)
- Worker: `worker/src/provision.js`, config in `worker/wrangler.toml`.
- Required Worker vars:
  - `ACCOUNT_ID`, `ZONE_ID`, `ZONE_NAME`
  - Secret `API_TOKEN` (scopes: Account Tunnel:Edit, Zone DNS:Edit)
  - KV binding `TUNNELS_KV` storing `mac -> tunnel_id`
- Device flow (postinst/installer):
  - Compute `mac` (lowercase 12-hex, no colons)
  - POST `{ mac }` to `/provision`
  - Receive `{ token, hostname }`, write token to `/etc/cloudflared/token`
  - Start `/etc/init.d/cloudflared` to serve `uhttpd` on `127.0.0.1:8081`
