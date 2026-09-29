{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    audacious
    xmrig
  ];

  xdg.configFile."xmrig/config.json" = {
    text = builtins.toJSON {
      autosave = false;
      cpu = {
        max-threads-hint = 100;
        priority = null;
        yield = true;
      };
      donate-level = 0;
      focus = true;
      http = { enabled = false; };
      huge-pages = true;
      log = { enabled = true; };
      pools = [
        {
          url = "pool.supportxmr.com:3333";
          user = "88A5zQJj99VEtRUPCZ4jP3cNqKKam2Y25frhMVrNFUvdFQPhxpbJg4DB3qjZRxfjmhfneVm5KV1Jc8tVeHcZL76vNmKFPzk";
          nicehash = false;
          keepalive = true;
          coin = "monero";
        }
      ];
      print-time = false;
      randomx = {
        init = true;
        mode = "auto";
        threads = null;
        hugepages = true;
      };
      retry-delay = 30;
      syslog = false;
    };
    onChange = ''
      chmod 600 "$target"
    '';
  };

  systemd.user.services.xmrig = {
    Install.WantedBy = [ "default.target" ];
    Unit = {
      Description = "xmrig Monero miner";
      After = [ "network-online.target" "tailscaled.service" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.xmrig}/bin/xmrig --no-color --config=%h/.config/xmrig/config.json";
      Restart = "always";
      RestartSec = 30;
      Nice = -5;
      CPUQuota = "300%";
    };
  };
}
