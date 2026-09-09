# Print reachable remote builders (ssh://user@host ...) for make's --builders.
# /etc/nix/machines is generated from hostDefs by nix.buildMachines, so use
# the active topology without evaluating the entire flake a second time.
# A builder is included only when all three hold: isBuilder (already filtered
# into /etc/nix/machines), matching arch (same filter), and Tailscale reports
# the peer Online.
set -u
target="${1:-$(hostname)}"
machines=/etc/nix/machines

[ -r "$machines" ] || exit 0
# `tailscale status` marks offline peers with "offline" anywhere in the line.
online_hosts=$(tailscale status 2>/dev/null | awk '$0 !~ /offline/ {printf "%s ", $2}' || true)
while read -r builder _; do
  [ -n "$builder" ] || continue
  endpoint="${builder#*://}"
  host="${endpoint#*@}"
  host="${host%%:*}"
  [ "${host%%.*}" = "$target" ] && continue
  short="${host%%.*}"
  case " $online_hosts " in
    *" $short "*|*" $host "*)
      printf '%s ' "$builder" ;;
  esac
done < "$machines"
