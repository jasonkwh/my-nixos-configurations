# Headless first-boot Tailscale enrolment (fleet-wide, reusable module).
#
# Problem: a headless board (bcm2711, bcm2710a1, ...) boots with no screen or
# keyboard; `tailscale up` normally needs one interactive auth.
#
# Solution: a Tailscale auth key (admin console: reusable=on when shared by
# multiple boards, ephemeral=on, pre-approved, tag:fleet) is stored in the
# fleet secrets file
# ~/.secrets/headless-env (key: ts_auth_key) by
# cluster/misc/export-headless-env.sh — same file as the Wi-Fi credentials,
# same rsync-at-flash workflow as hermes-env. At boot a oneshot service
# reads it, joins the tailnet, and marks itself done. From then on the node
# is reachable at jasonkwh-<host>.tail0c0276.ts.net and fleet SSH works
# immediately (Tailscale SSH handles identity; openssh stays key-only/
# off-LAN per common/configuration.nix).
#
# Rotating/re-enrolling: put a fresh key in headless-env and delete
# /var/lib/tailscale on the board.
{ config, lib, pkgs, username, ... }:

{
  systemd.services.tailscale-enrol = {
    description = "First-boot Tailscale enrolment from headless-env auth key";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "tailscaled.service" "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = "-/home/${username}/.secrets/headless-env";
      ExecStart = pkgs.writeShellScript "ts-enrol" ''
        if ${config.services.tailscale.package}/bin/tailscale status --peers=false >/dev/null 2>&1; then
          ${config.services.tailscale.package}/bin/tailscale set --ssh
          echo "tailscale-enrol: already enrolled; Tailscale SSH enabled"
          exit 0
        fi
        AUTH_KEY="''${TS_AUTH_KEY:-''${ts_auth_key:-}}"
        if [ -n "$AUTH_KEY" ]; then
          exec ${config.services.tailscale.package}/bin/tailscale up \
            --auth-key="$AUTH_KEY" --hostname="$(cat /etc/hostname)" --ssh
        fi
        echo "tailscale-enrol: not enrolled and no ts_auth_key in headless-env; skipping"
      '';
    };
  };
}
