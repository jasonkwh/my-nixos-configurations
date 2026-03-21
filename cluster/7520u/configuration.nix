
{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/configuration.nix
  ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelModules = [ "nft_expr_counter" ];

    # Fix for Realtek RTL8821CE intermittent disconnections
    extraModprobeConfig = ''
      options rtw88_core disable_lps_deep=Y disable_lps=Y
      options rtw88_pci disable_msi=Y disable_aspm=Y
      options rtw88_8821ce disable_lps_deep=Y disable_lps=Y ant_sel=2
    '';

    kernelParams = [
      "pcie_aspm.policy=performance"
      "pci=noaer"
      "iwlwifi.power_save=0"
      "rtw88_core.disable_lps_deep=Y"
      "rtw88_pci.disable_msi=Y"
      # Use the modern AMD P-State driver for better CPU frequency scaling
      "amd_pstate=active"
      # Unlock all amdgpu power management feature flags
      "amdgpu.ppfeaturemask=0xffffffff"
      # Reduce watchdog overhead
      "nowatchdog"
    ];

    kernel.sysctl = {
      # Lower swappiness since we use zram; avoids premature disk swap
      "vm.swappiness" = 10;
      # Reduce dirty page write-back latency
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
    };
  };

  networking = {
    hostName = "jasonkwh-7520u"; # Define your hostname.
    networkmanager.wifi.powersave = false;
  };

  # Compressed RAM swap — reduces memory pressure and avoids slow disk swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  hardware.graphics.extraPackages = with pkgs; [
    # VA-API and VDPAU for hardware video decode/encode (mpv, ffmpeg, browser video)
    mesa
    libva-utils
    rocmPackages.clr.icd
  ];

  programs = {
    # Gamemode: temporarily boosts CPU governor and GPU clocks during gaming
    gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };
  };

  services = {
    xserver = {
      videoDrivers = [ "amdgpu" ];
    };

    # Periodic SSD TRIM to maintain write performance
    fstrim = {
      enable = true;
      interval = "weekly";
    };

    # Distribute hardware IRQs across CPU cores
    irqbalance.enable = true;

    # KDE Plasma integrates natively with power-profiles-daemon
    # Provides balanced/performance/power-saver profiles via the system tray
    power-profiles-daemon.enable = true;

    k3s = {
      enable = false;
      role = "server";
      extraFlags = toString [
        "--tls-san=${config.networking.hostName}"
        "--flannel-iface=wlp2s0"
        "--disable-network-policy"
      ];
    };

    # use evtest to find out the device id & key num
    udev.extraHwdb = ''
      evdev:atkbd:*
        KEYBOARD_KEY_56=leftshift
    '';

    resilio = {
      enable = true;
      enableWebUI = true;
      httpListenAddr = "127.0.0.1";
      httpListenPort = 9000;
    };
  };

  users.users.jasonkwh = {
    extraGroups = [ "rslsync" ];
    homeMode = "0750";
  };

  users.users.rslsync.extraGroups = [ "users" ];
}
