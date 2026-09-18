# Reachable builders as a nix.conf --builders value (semicolon-separated;
# Make's $(shell) collapses newlines). Prefer the generation list over a
# wiped /etc/nix/machines. All online peers included; target host skipped.
set -u
target="${1:-$(hostname)}"
target="${target%%.*}"

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
  case " $online_hosts " in
    *" $short "*|*" $host "*)
      printf '%s%s' "$sep" "$line"
      sep="; "
      ;;
  esac
done < "$machines"
