# Print reachable remote builders (ssh://user@host ...) for make's --builders.
# /etc/nix/machines is generated from hostDefs by nix.buildMachines, so use
# the active topology without evaluating the entire flake a second time.
set -u
target="${1:-$(hostname)}"
machines=/etc/nix/machines

[ -r "$machines" ] || exit 0
while read -r builder _; do
  [ -n "$builder" ] || continue
  endpoint="${builder#*://}"
  host="${endpoint#*@}"
  host="${host%%:*}"
  [ "${host%%.*}" = "$target" ] && continue
  nc -z -w 2 "$host" 22 >/dev/null 2>&1 && printf '%s ' "$builder"
done < "$machines"
