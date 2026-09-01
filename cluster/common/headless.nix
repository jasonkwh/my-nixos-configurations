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

  # Broadcom firmware + extlinux boot, no UEFI (all Pi boards).
  boot.loader = lib.mkForce {
    grub.enable = false;
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = false;
    generic-extlinux-compatible.enable = true;
  };

  # Shared zram profile; swappiness stays low since swap is compressed RAM.
  boot.kernel.sysctl."vm.swappiness" = 10;
  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  # SD image rootfs is sized to contents; grow to fill the card on first boot.
  # Device detected at runtime — Pi 4B enumerates its card as mmcblk1.
  systemd.services.sd-resize = {
    description = "Grow root partition and filesystem to fill the SD card";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    path = [ pkgs.cloud-utils pkgs.util-linux ];
    script = ''
      ROOT_SRC="$(findmnt -nro SOURCE /)"
      ROOT_DEV="$(basename "$ROOT_SRC")"          # e.g. mmcblk0p2 / mmcblk1p2
      DISK="''${ROOT_DEV%p[0-9]*}"                # e.g. mmcblk0
      PART="''${ROOT_DEV##*p}"                    # e.g. 2
      [ -e "/dev/$DISK" ] || { echo "sd-resize: /dev/$DISK missing"; exit 1; }
      if ! growpart "/dev/$DISK" "$PART"; then
        # growpart exit 1 = partition already full size, not an error
        [ $? -eq 1 ] || exit 1
      fi
      resize2fs "$ROOT_SRC"
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
