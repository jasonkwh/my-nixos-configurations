{ config, lib, pkgs, username, ... }:

let
  swapUuid = "ae05e73d-58d6-4acb-8111-cecec356bd5f";
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
        device = lib.mkForce "/dev/sda"; # Patriot P220, MBR install
      };
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
    };
    # 17GiB swap > max RAM: hibernation image always fits.
    resumeDevice = "/dev/disk/by-uuid/${swapUuid}";
    # Fixed-mux VAIO CB: HD 3000 fused off, HD6630M is the only GPU.
    kernelParams = [ "radeon.dpm=1" ];
  };

  services.xserver.videoDrivers = [ "modesetting" "radeon" ];

  # X11 session needs QT_IM_MODULE/XMODIFIERS, which waylandFrontend=true omits.
  i18n.inputMethod.fcitx5.waylandFrontend = lib.mkForce false;

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
