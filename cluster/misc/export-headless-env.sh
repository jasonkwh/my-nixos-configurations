#!/usr/bin/env bash
# Build a headless-env secrets file from the build host's live state:
#   - ssid_home / psk_home : active NetworkManager Wi-Fi
#   - ts_auth_key          : Tailscale auth key (prompted; generate in the
#     admin console as reusable=off, ephemeral=on, pre-approved, tag:fleet)
# Consumed by cluster/common/wifi-home.nix and tailscale-enrol.nix on
# headless boards via LoadCredential/environment file injection.
# Run on a laptop, then rsync ~/.secrets to the board with the fleet secrets.
set -euo pipefail

OUT="${1:-/home/jasonkwh/.secrets/headless-env}"
install -d -m 700 "$(dirname "$OUT")"

CONN="$(nmcli -t -f NAME,TYPE connection show --active | grep ':802-11-wireless' | head -1 | cut -d: -f1)"
[ -n "$CONN" ] || { echo "no active wireless connection" >&2; exit 1; }

SSID="$(nmcli -g 802-11-wireless.ssid connection show "$CONN" | head -1)"
# nmcli can return several lines (duplicate profiles); take the first
PSK="$(nmcli -s -g 802-11-wireless-security.psk connection show "$CONN" | head -1)"
[ -n "$SSID" ] && [ -n "$PSK" ] || { echo "no ssid/psk on $CONN" >&2; exit 1; }

umask 177
{
  # Raw values, no %q: consumers (wpa ext:, systemd EnvironmentFile) parse
  # literally and do not do shell backslash-unescape.
  printf 'ssid_home=%s\n' "$SSID"
  printf 'psk_home=%s\n' "$PSK"
  if [ -n "${TS_AUTH_KEY:-}" ]; then
    printf 'ts_auth_key=%s\n' "$TS_AUTH_KEY"
  elif [ -t 0 ]; then
    printf 'ts_auth_key=%s\n' "$(read -rp 'Tailscale auth key (empty to skip): ' k; echo "$k")"
  fi
} > "$OUT"
chmod 600 "$OUT"
echo "wrote $OUT (ssid: $SSID)"
