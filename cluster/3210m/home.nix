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
          url = "supportxmr.com:443";
          user = "88A5zQJj99VEtRUPCZ4jP3cNqKKam2Y25frhMVrNFUvdFQPhxpbJg4DB3qjZRxfjmhfneVm5KV1Jc8tVeHcZL76vNmKFPzk";
          nicehash = false;
          keepalive = true;
          coin = "monero";
        }
      ];
      print-time = false;
      randomx = {
        init = false;
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
    Unit.Description = "xmrig Monero miner";
    Install.WantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xmrig}/bin/xmrig --no-color --config=$HOME/.config/xmrig/config.json";
      Restart = "always";
      RestartSec = 30;
    };
    processConfig = {
      Nice = -5;
    };
  };
}
