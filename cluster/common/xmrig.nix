# Hugepages are NixOS; the miner config is Home Manager.
{ config, lib, pkgs, username, monero, ... }:

{
  # ~2.3GiB of 2MiB pages. Without them RandomX falls back and loses ~20%.
  boot.kernel.sysctl."vm.nr_hugepages" = 1200;

  # MSR mod needs the device node and CAP_SYS_RAWIO. The wrapper is first on PATH.
  boot.kernelModules = [ "msr" ];

  security.wrappers.xmrig = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_rawio+ep";
    source = "${pkgs.xmrig}/bin/xmrig";
  };

  home-manager.users.${username} = {
    home.packages = [ pkgs.xmrig ];

    xdg.configFile."xmrig/config.json" = {
      text = builtins.toJSON {
        autosave = false;
        cpu = {
          huge-pages = true; # 6.x ignores a top-level huge-pages key
          max-threads-hint = 100;
          priority = null;
          yield = true;
        };
        donate-level = 0; # nixpkgs already patches the minimum to 0
        http = { enabled = false; };
        pools = [
          {
            url = monero.pool.url;
            user = monero.wallet;
            pass = config.networking.hostName; # MoneroOcean worker name
            nicehash = false;
            keepalive = true;
            coin = "monero";
            tls = monero.pool.tls;
          }
        ];
        print-time = 0;
        randomx = {
          init = -1; # auto dataset-init threads; mining threads come from max-threads-hint
          mode = "auto";
        };
        retry-pause = 10;
        syslog = false;
      };
    };
  };
}
