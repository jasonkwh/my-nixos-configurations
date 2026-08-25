# Laptop-only system configuration.
# Imported only when the host is created with isLaptop = true in flake.nix;
# desktop machines (e.g. the Mac Pro trashcan) skip this file entirely.
{ pkgs, lib, ... }:

{
  # Periodic SSD TRIM to maintain write performance.
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Distribute hardware IRQs across CPU cores.
  services.irqbalance.enable = true;

  hardware = {
    steam-hardware.enable = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # Hardware probing / diagnostics tools useful on portable machines.
    hw-probe
    pciutils
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages;

    kernel.sysctl = {
      # Lower swappiness since we use zram; avoids premature disk swap
      "vm.swappiness" = 10;
      # Reduce dirty page write-back latency
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
    };
  };

  # Compressed RAM swap — reduces memory pressure and avoids slow disk swap
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  networking.networkmanager.wifi.powersave = false;

  services = {
    # Provides KDE balanced, performance, and power-saver profiles.
    power-profiles-daemon.enable = true;

    upower = {
      enable = true;
      # If the battery becomes critical, do a clean shutdown instead of
      # entering a potentially unrecoverable low-power suspend state.
      criticalPowerAction = "PowerOff";
    };

    logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };
  };
}
