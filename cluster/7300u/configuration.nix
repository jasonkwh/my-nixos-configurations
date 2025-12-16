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
      role = "agent"; # or agent
      serverAddr = "https://jasonkwh-7520u.local:6443";
      token = "K107554bc617e907cf70466a0af218deb9c9ae15f18a29b3033da9583b51be61f6e::server:f9a22d3080e522af42b6e380c413b17d";
        extraFlags = [
          "--flannel-iface=wlp58s0"
        ];
    };
  };
}
