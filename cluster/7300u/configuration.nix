{ lib, pkgs, ... }:

{
  imports =
    [
      ../common/configuration.nix
    ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ../common/home-gui.nix
      ../common/home-gpu.nix
      ./home.nix
    ];
  };

  boot = {
    kernelPackages = pkgs.linuxPackages;
    kernelModules = [ "nft_expr_counter" ];
    kernelParams = [
      "nowatchdog"
    ];
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  networking = {
    hostName = "jasonkwh-7300u"; # Define your hostname.
  };

  services = {
    xserver = {
      videoDrivers = [ "intel" ];
    };
    thermald.enable = true;
    fstrim.enable = true;
    power-profiles-daemon.enable = true;
    irqbalance.enable = true;

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        scrollMethod = "twofinger";
        clickMethod = "clickfinger";
        accelProfile = "flat";
        disableWhileTyping = true;
        accelSpeed = "0.0";
      };
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

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics.extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
}
