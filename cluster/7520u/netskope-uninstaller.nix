# Companion to netskope.nix: removes the client the vendor installer laid
# down outside Nix (/opt/netskope, stagent services). Run manually with sudo
# before/after setting shengos.netskope.enable = false.
{ config, lib, pkgs, ... }:

let
  cfg = config.shengos.netskope;

  netskope-uninstaller = pkgs.buildFHSEnv {
    name = "netskope-uninstaller";
    targetPkgs = pkgs: with pkgs; [ bash coreutils procps systemd ];
    # Prefer the vendor's own uninstall script; fall back to manual teardown.
    runScript = pkgs.writeShellScript "netskope-uninstall" ''
      if [ -x /opt/netskope/stagent/uninstall/nsinstall.sh ]; then
        /opt/netskope/stagent/uninstall/nsinstall.sh -y uninstall
      elif [ -x /opt/netskope/stagent/nsinstall.sh ]; then
        /opt/netskope/stagent/nsinstall.sh -y uninstall
      else
        echo "no vendor uninstall script found, manual teardown"
        systemctl stop stagentd 2>/dev/null || true
        systemctl disable stagentd 2>/dev/null || true
        rm -rf /opt/netskope /etc/systemd/system/stagentd.service
        systemctl daemon-reload
      fi
      echo "netskope client removed"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ netskope-uninstaller ];
  };
}
