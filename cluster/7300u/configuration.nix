{ lib, ... }:

{
  imports =
    [
      ../common/configuration.nix
    ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  boot.kernelModules = [ "nft_expr_counter" ];

  networking = {
    hostName = "jasonkwh-7300u"; # Define your hostname.
  };

  services = {
    xserver = {
      videoDrivers = [ "intel" ];
    };

    k3s = {
      enable = false;
      role = "agent";
      serverAddr = "https://jasonkwh-7520u.local:6443";
      tokenFile = "/var/lib/k3s-token";
      extraFlags = [
        "--flannel-iface=wlp58s0"
      ];
    };
  };
}
