
{ config, lib, pkgs, ... }:
let
  swapUuid = "97c60ea8-adcf-444b-a44d-e9eeac24138f";
  wifiIface = "wlp2s0";
in
{
  imports = [
    ../common/configuration.nix
  ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ../common/home-gui.nix
      ./home.nix
    ];
  };

  hardware = {
    cpu.amd.updateMicrocode = true;

    graphics.extraPackages = with pkgs; [
      # VA-API and VDPAU for hardware video decode/encode (mpv, ffmpeg, browser video)
      mesa
      libva-utils
      rocmPackages.clr.icd
    ];
  };

  boot = {
    kernelPackages = pkgs.linuxPackages;
    # Resume hibernation image from the 7520u swap partition.
    resumeDevice = "/dev/disk/by-uuid/${swapUuid}";

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
      # Work around amdgpu/KWin pageflip timeout hangs on this laptop.
      "amdgpu.dcdebugmask=0x10"
      # Use the modern AMD P-State driver for better CPU frequency scaling
      "amd_pstate=active"
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

  # Keep a single authoritative swap definition and prevent duplicate entries
  # from other imported modules from being merged into /etc/fstab.
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-uuid/${swapUuid}";
      discardPolicy = "both";
    }
  ];

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

  programs = {
    steam = {
      enable = true;
    };

    wireshark = {
      enable = true;
    };

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
    fwupd.enable = true;

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
        "--flannel-iface=${wifiIface}"
        "--disable-network-policy"
      ];
    };

    # use evtest to find out the device id & key num
    udev.extraHwdb = ''
      evdev:atkbd:*
        KEYBOARD_KEY_56=leftshift
    '';

    resilio = {
      enable = false;
      enableWebUI = false;
      httpListenAddr = "127.0.0.1";
      httpListenPort = 9000;
    };
  };
}
