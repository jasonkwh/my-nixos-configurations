{ config, lib, pkgs, ... }:

{
  imports =
    [
      ../common/configuration.nix
    ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ../common/home-gui.nix
      ./home.nix
    ];
  };

  time.timeZone = "Australia/Melbourne";

  boot = {
    kernelPackages = pkgs.linuxPackages;
    kernelParams = [
      "nowatchdog"
      "pcie_aspm=off"
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
      videoDrivers = [ "intel" "nvidia" ];
    };
    hardware.bolt.enable = true;
    thermald.enable = true;

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
    nvidia = {
      modesetting.enable = true;
      # GTX970 specific settings
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    };
    graphics.extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
}
