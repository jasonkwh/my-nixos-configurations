{ config, lib, pkgs, username, ... }:

let
  # 3210m's own swap partition (from hardware-configuration.nix).
  swapUuid = "aca6a618-c225-4420-b8c8-bd96575c3377";
in
{
  imports = [
    ../common/configuration.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  time.timeZone = "Australia/Melbourne";

  # VAIO SVS131 (i3-3210M) boots legacy BIOS from the MBR — override the
  # fleet-default systemd-boot/EFI setup.
  boot = {
    loader = {
      grub = {
        enable = lib.mkForce true;
        device = lib.mkForce "/dev/sda";
      };
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
    };

    # Hibernate resumes from the swap partition.
    resumeDevice = "/dev/disk/by-uuid/${swapUuid}";
  };

  # X11 session needs QT_IM_MODULE/XMODIFIERS, which waylandFrontend=true omits.
  i18n.inputMethod.fcitx5.waylandFrontend = lib.mkForce false;

  # Storage tuning layered onto hardware-configuration.nix (kept untouched):
  # noatime reduces SSD writes; trim via fstrim.
  fileSystems."/" = {
    options = [ "noatime" ];
  };

  # Single authoritative swap definition; prevent duplicate fstab entries.
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-uuid/${swapUuid}";
      discardPolicy = "both";
    }
  ];

  # Ivy Bridge thermal management for an aging VAIO cooling system.
  services.thermald.enable = true;
}
