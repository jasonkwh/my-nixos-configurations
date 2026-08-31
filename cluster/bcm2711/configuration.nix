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

  # Secrets are baked into the SD image at build time (make image sets
  # SECRETS_SRC); this module only applies inside the sd-card image variant.
  # Import the sd-card module directly instead of relying on image.modules
  # defaults — the default path probes pkgs.targetPlatform (renamed alias,
  # eval warning on every image build).
  image.modules.sd-card = lib.mkForce {
    imports = [
      "${pkgs.path}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ../common/sd-image-secrets.nix
    ];
    image.baseName = "shengos-bcm2711";
  };
}
