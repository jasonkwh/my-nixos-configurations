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

  # Optimus: HD 4000 drives the display, GT 640M LE offload via legacy 470
  # (Kepler; if lspci shows device id 1140 it's Fermi — switch to legacy_390).
  # PCI bus IDs must be filled in from `lspci | grep -E "VGA|3D"` after boot.
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  # Optimus PRIME offload: HD 4000 drives the display, GT 640M LE (GK107,
  # 10de:0fd3 Kepler) offload via legacy 470. Bus IDs from lspci on host.
  hardware.nvidia = {
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";   # 00:02.0
      nvidiaBusId = "PCI:1:0:0";  # 01:00.0
    };
    package = config.boot.kernelPackages.nvidia_x11_legacy470;
    powerManagement.enable = false;
    # legacy 470 has no open-kernel-module variant; upstream default (null
    # for driver >= 560) breaks the !open assertion — pin it to false.
    open = lib.mkForce false;
  };
  # Allow unfree NVIDIA driver (license acceptance lives in nixpkgs.config).
  nixpkgs.config.nvidia.acceptLicense = true;

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
