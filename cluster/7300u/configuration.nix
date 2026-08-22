{ lib, pkgs, username, ... }:

{
  imports =
    [
      ../common/configuration.nix
    ];

  home-manager.users.${username} = {
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
    networkmanager.wifi.powersave = false;
  };

  services = {
    xserver = {
      videoDrivers = [ "modesetting" ];
    };
    thermald.enable = true;
    # Provides KDE balanced, performance, and power-saver profiles.
    power-profiles-daemon.enable = true;

    upower = {
      enable = true;
      # If the battery becomes critical, do a clean shutdown instead of
      # entering a potentially unrecoverable low-power suspend state.
      criticalPowerAction = "PowerOff";
    };

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

    # k3s = {
    #   enable = false;
    #   role = "agent";
    #   serverAddr = "https://jasonkwh-7520u.local:6443";
    #   token = "";
    #   extraFlags = [
    #     "--flannel-iface=wlp58s0"
    #   ];
    # };

    logind = {
      settings = {
        Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchDocked = "ignore";
          HandleLidSwitchExternalPower = "ignore";
        };
      };
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
