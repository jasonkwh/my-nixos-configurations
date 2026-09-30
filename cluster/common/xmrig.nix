# XMRig (Monero) — shared by hosts that mine. Import at NixOS level:
# the RandomX hugepage sysctl and the Home Manager config file are
# different module systems, so this file carries both.
{ config, lib, pkgs, username, monero, ... }:

let
  worker = config.networking.hostName;
in
{
  # RandomX dataset init wants ~2.3GiB in 2MiB pages; without them xmrig
  # falls back to 4KiB pages and loses ~20% hashrate.
  boot.kernel.sysctl."vm.nr_hugepages" = 1200;

  # Started by hand: plain `xmrig` reads this file from its default path.
  home-manager.users.${username} = {
    home.packages = [ pkgs.xmrig ];

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
            url = monero.pool.url;
            user = monero.wallet + "+" + worker;
            nicehash = false;
            keepalive = true;
            coin = "monero";
            tls = monero.pool.tls;
          }
        ];
        print-time = false;
        randomx = {
          init = true;
          mode = "auto";
          threads = null;
          hugepages = true;
        };
        retry-delay = 10;
        syslog = false;
      };
      onChange = ''
        chmod 600 "$target"
      '';
    };
  };
}
