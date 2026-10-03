# User-level XMRig: the package and ~/.config/xmrig.json.
# Imported by the NixOS module (cluster/common/nixos/xmrig.nix) and by the
# SteamOS home configuration, which cannot apply the kernel setup.
{ pkgs, monero, hostName, isSteamMachine ? false, ... }:

{
  home.packages = [ pkgs.xmrig ];

  xdg.configFile."xmrig.json" = {
    text = builtins.toJSON {
      autosave = false;
      cpu = {
        huge-pages = !isSteamMachine;
        max-threads-hint = 100;
        priority = null;
        yield = true;
      };
      donate-level = 0;
      http = {
        enabled = true;
        host = "0.0.0.0";
        port = 16000;
        restricted = true;
      };
      pools = [
        {
          url = monero.pool.url;
          user = monero.wallet;
          pass = hostName;
          nicehash = false;
          keepalive = true;
          coin = "monero";
          tls = monero.pool.tls;
        }
      ];
      print-time = 0;
      randomx = {
        init = -1;
        mode = "auto";
      };
      retry-pause = 10;
      syslog = false;
    };
  };
}
