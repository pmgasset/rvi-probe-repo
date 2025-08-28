#!/bin/sh
# BusyBox ash compatible
set -eu

log() { logger -t rvi-probe "$*"; }
UCI() { uci -q get rviprobe.config.$1 2>/dev/null || echo ""; }

WORKER_URL="$(UCI worker_url)"
INTERVAL="$(UCI telemetry_interval)"; [ -z "$INTERVAL" ] && INTERVAL=300
ENABLED="$(UCI enabled)"; [ -z "$ENABLED" ] && ENABLED=1

board_name() { cat /tmp/sysinfo/board_name 2>/dev/null || echo "unknown"; }
model() { ubus -S call system board 2>/dev/null | jq -r '.model // "unknown"' 2>/dev/null || echo unknown; }
firmware() { ubus -S call system board 2>/dev/null | jq -r '.release.description // ""' 2>/dev/null || echo unknown; }

get_if() {
	IF=$(uci -q get network.wan.ifname 2>/dev/null || echo "" )
	[ -n "$IF" ] && { echo "$IF"; return; }
	ip -4 route show default 2>/dev/null | awk '{print $5; exit}'
}

cell_stats() {
	if command -v uqmi >/dev/null 2>&1; then
		MODEM=$(ls /dev/cdc-wdm* 2>/dev/null | head -n1 || true)
		[ -n "$MODEM" ] && uqmi -d "$MODEM" --get-signal-info 2>/dev/null || true
	elif command -v mmcli >/dev/null 2>&1; then
		mmcli -m 0 --signal 2>/dev/null || true
	fi
}

post_json() {
	URL="$1"; DATA="$2"
	[ -z "$URL" ] && return 0
	curl -fsS --max-time 10 -H 'Content-Type: application/json' -d "$DATA" "$URL" >/dev/null || true
}

while :; do
	[ "$ENABLED" = "0" ] && sleep "$INTERVAL" && continue
	IF=$(get_if)
	IPV4=$(ip -4 addr show "$IF" 2>/dev/null | awk '/inet /{print $2; exit}')
	PING_MS=$(ping -c1 -W1 1.1.1.1 2>/dev/null | awk -F'/' '/rtt/{print $5}')
	LOSS=$(ping -c3 -W1 1.1.1.1 2>/dev/null | awk -F"," '/packets transmitted/{print $3+0}' | tr -dc '0-9')
	CELL=$(cell_stats | tr '\n' ' ' | sed 's/\"/\\\"/g')
	MODEL=$(model | sed 's/\"/\\\"/g')
	FW=$(firmware | sed 's/\"/\\\"/g')
	HOST=$(hostname)
	DATA=$(printf '{"host":"%s","board":"%s","model":"%s","firmware":"%s","if":"%s","ip":"%s","rtt_ms":"%s","loss":"%s","cell":"%s"}' \
		"$HOST" "$(board_name)" "$MODEL" "$FW" "$IF" "$IPV4" "$PING_MS" "$LOSS" "$CELL")
	post_json "$WORKER_URL" "$DATA"
	sleep "$INTERVAL"
done
