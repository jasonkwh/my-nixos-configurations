{ config, lib, pkgs, username, monero, ... }:

{
  boot.kernel.sysctl."vm.nr_hugepages" = 1200;

  boot.kernelModules = [ "msr" ];
  boot.kernelParams = [ "msr.allow_writes=on" ];

  services.udev.extraRules = ''
    KERNEL=="msr[0-9]*", GROUP="wheel", MODE="0660"
  '';

  security.wrappers.xmrig = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_rawio+ep";
    source = "${pkgs.xmrig}/bin/xmrig";
  };

  home-manager.users.${username} = {
    home.packages = [ pkgs.xmrig ];

    xdg.configFile."xmrig.json" = {
      text = builtins.toJSON {
        autosave = false;
        cpu = {
          huge-pages = true;
          max-threads-hint = 100;
          priority = null;
          yield = true;
        };
        donate-level = 0;
        http = {
          enabled = true;
          host = "127.0.0.1";
          port = 16000;
          restricted = true;
        };
        pools = [
          {
            url = monero.pool.url;
            user = monero.wallet;
            pass = config.networking.hostName;
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
  };
}
