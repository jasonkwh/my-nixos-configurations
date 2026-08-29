# Raspberry Pi Zero 2 W (BCM2710A1, aarch64) — headless MQTT thin client.
{ lib, pkgs, username, ... }:

{
  imports = [
    ../common/configuration.nix
    ./usb-gadget.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  # 512MB RAM — same SD-card profile as bcm2711 but tighter: zram is not a
  # nice-to-have here, it is the only swap.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };
  boot.kernel.sysctl."vm.swappiness" = 10;

  time.timeZone = "Australia/Melbourne";

  services.fstrim.enable = lib.mkForce false;

  # Pi boots via Broadcom firmware + extlinux, no UEFI — override the
  # systemd-boot/EFI defaults from common (which are for the x86 hosts).
  # grub.enable=false is also required: without a nixos-hardware module doing
  # it for us (bcm2711 gets that from nixos-hardware), grub defaults to true.
  boot.loader = lib.mkForce {
    grub.enable = false;
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
  };
}
