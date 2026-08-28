# RPi Zero 2 W (BCM2710A1) hardware layout for the SD-card image.
# NOTE: nixos-hardware has no Zero 2 W module (only Pi 2/3/4/5); the Zero 2 W
# (BCM2710A1, same SoC generation as Pi 3) boots via the generic aarch64 SD
# image + RPi firmware. This file only covers mounts.
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ]; # zramSwap instead — see common/headless.nix

  # Enables DHCP on each ethernet and wireless interface.
  networking.useDHCP = lib.mkDefault true;
  # Zero 2 W is wireless-only (no ethernet jack).
  networking.wireless.interfaces = [ "wlan0" ];
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
