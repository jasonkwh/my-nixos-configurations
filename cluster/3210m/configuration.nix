{ config, lib, pkgs, username, ... }:

let
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

  # Legacy-BIOS VAIO; fleet default is systemd-boot/EFI.
  boot = {
    loader = {
      grub = {
        enable = lib.mkForce true;
        device = lib.mkForce "/dev/sda";
      };
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
    };
    resumeDevice = "/dev/disk/by-uuid/${swapUuid}";
  };

  # X11 session needs QT_IM_MODULE/XMODIFIERS, which waylandFrontend=true omits.
  i18n.inputMethod.fcitx5.waylandFrontend = lib.mkForce false;

  # Built-in DVD drive.
  users.users.jasonkwh.extraGroups = [ "cdrom" ];

  fileSystems."/" = {
    options = [ "noatime" ];
  };

  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-uuid/${swapUuid}";
      discardPolicy = "both";
    }
  ];

  services.thermald.enable = true;
}
