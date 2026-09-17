# Reachable builders as a nix.conf --builders value (semicolon-separated;
# Make's $(shell) collapses newlines). Prefer the generation list over a
# wiped /etc/nix/machines. Peers at least as fast as this host (local-speed).
set -u
target="${1:-$(hostname)}"
target="${target%%.*}"
local_speed=1
if [ -r /etc/nix/local-speed ]; then
  local_speed=$(cat /etc/nix/local-speed)
fi

machines=""
for candidate in \
  /run/current-system/etc/nix/machines \
    /etc/static/nix/machines \
    /etc/nix/machines
do
  if [ -r "$candidate" ]; then
    machines="$candidate"
    break
  fi
done
[ -n "$machines" ] || exit 0

# `tailscale status` marks offline peers with "offline" anywhere in the line.
online_hosts=$(tailscale status 2>/dev/null | awk '$0 !~ /offline/ {printf "%s ", $2}' || true)
sep=""
while read -r line; do
  [ -n "$line" ] || continue
  builder="${line%% *}"
  endpoint="${builder#*://}"
  host="${endpoint#*@}"
  host="${host%%:*}"
  short="${host%%.*}"
  [ "$short" = "$target" ] && continue
  speed=$(printf '%s' "$line" | awk '{print $5}')
  [ "$speed" -ge "$local_speed" ] || continue
  case " $online_hosts " in
    *" $short "*|*" $host "*)
      printf '%s%s' "$sep" "$line"
      sep="; "
      ;;
  esac
done < "$machines"
