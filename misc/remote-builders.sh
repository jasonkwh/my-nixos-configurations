# Print reachable remote builders (ssh://user@host ...) for make's --builders.
# Builder list comes from the flake (hostDefs.isBuilder), not hardcoded.
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:-$(hostname)}"
hosts=$(nix eval --impure --raw --expr \
  "(builtins.getFlake (toString $repo)).fleetBuilderHosts.${target}" \
  --apply 'builtins.concatStringsSep " "' 2>/dev/null) || exit 0
for h in $hosts; do
  nc -z -w 2 "${h%%.*}" 22 >/dev/null 2>&1 && printf '%s ' "ssh://jasonkwh@$h"
done
