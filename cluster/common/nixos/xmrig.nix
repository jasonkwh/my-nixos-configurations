{ pkgs, username, ... }:

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

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 16000 ];

  home-manager.users.${username}.imports = [ ../home/xmrig.nix ];
}
