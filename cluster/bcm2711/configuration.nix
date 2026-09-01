# Raspberry Pi 4B (BCM2711, aarch64) — headless Hermes node.
{ lib, pkgs, username, ... }:

{
  imports = [
    ../common/configuration.nix
    ./gadget-downlink.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  # 4GB RAM + SD card — compressed RAM swap gives headroom under memory
  # spikes while avoiding swap-on-SD writes.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  boot.kernel.sysctl."vm.swappiness" = 10;

  time.timeZone = "Australia/Melbourne";

  # Pi boots via Broadcom firmware + extlinux, no UEFI — override the
  # systemd-boot/EFI defaults from common (which are for the x86 hosts).
  boot.loader = lib.mkForce {
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = false;
    generic-extlinux-compatible.enable = true;
  };

}
