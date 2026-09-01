# Imported only when a host sets isHeadless = true in flake.nix.
# Strips desktop/GUI/heavy bits so small boards (e.g. RPi 4B)
# spend their RAM and CPU on headless services instead of Plasma.
{ lib, pkgs, config, name, ... }:

{
  image.modules.sd-card = lib.mkForce {
    imports = [
      "${pkgs.path}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ./sd-image-secrets.nix
    ];
    image.baseName =
      "shengos-${name}-${config.system.nixos.release}-${pkgs.stdenv.hostPlatform.system}";
  };

  # Desktop stack off.
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  services.packagekit.enable = lib.mkForce false;
  services.flatpak.enable = lib.mkForce false;

  # No desktop, no input method, no printing by default on the board.
  i18n.inputMethod.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;

  # fwupd-efi cross-build broken on aarch64
  services.fwupd.enable = lib.mkForce false;

  # GUI programs and gaming stack off (steam, gamemode).
  programs.steam.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;

  # Graphics off entirely: enable=false alone doesn't stop mesa being pulled
  # in via extraPackages/enable32Bit, which forces the huge cross-LLVM+mesa
  # build into the SD-image closure.
  hardware.graphics = lib.mkForce {
    enable = false;
    enable32Bit = false;
    extraPackages = [ ];
    extraPackages32 = [ ];
  };

  # No container runtime on small boards.
  virtualisation.podman.enable = lib.mkForce false;

  # No KVM on ARM boards (x86 hosts keep the common default).
  nix.settings.system-features = lib.mkForce [ "nixos-test" "big-parallel" ];

  # SD card trim is unreliable/pointless on cheap cards (zram swap too).
  services.fstrim.enable = lib.mkForce false;

  # SD image rootfs is sized to contents; grow to fill the card on first boot.
  systemd.services.sd-resize = {
    description = "Grow root partition and filesystem to fill the SD card";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    unitConfig.ConditionPathExists = "/dev/mmcblk0";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.cloud-utils}/bin/growpart /dev/mmcblk0 2"
        "/run/current-system/sw/bin/resize2fs /dev/mmcblk0p2"
      ];
    };
  };
}
