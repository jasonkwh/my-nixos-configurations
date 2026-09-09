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

  # This VAIO (i5-2450M) is a legacy-BIOS machine booting from the Patriot
  # P220 SATA SSD's Master Boot Record — override the fleet-default
  # systemd-boot/EFI setup, which cannot work here.
  boot = {
    loader = {
      grub = {
        enable = lib.mkForce true;
        device = lib.mkForce "/dev/sda"; # Patriot P220, MBR install
      };
      systemd-boot.enable = lib.mkForce false;
      efi.canTouchEfiVariables = lib.mkForce false;
    };

    # Hibernation: resume from the P220 swap partition (17GiB > max RAM,
    # image always fits).
    resumeDevice = "/dev/disk/by-uuid/${swapUuid}";

    # intel_oc_wdt (OC watchdog, new in kernel 6.16) hangs boot/reboot on
    # this old VAIO PCH — blacklist it (ref: Arch/Fedora 6.16 breakage).
    blacklistedKernelModules = [ "intel_oc_wdt" ];

    # HD 3000 iGPU is fused off in firmware (fixed-mux VAIO CB, no 00:02.0).
    kernelParams = [
      # Old vbios can mis-clock the dGPU; start in "battery" profile,
      # raise via power_dpm_force_performance_level only while gaming.
      "radeon.dpm=1"
    ];
  };

  # Intel microcode updates (Sandy Bridge errata fixes).
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Single GPU: HD6630M drives everything via legacy radeon (TeraScale 2,
  # no amdgpu). No PRIME offload needed.
  services.xserver.videoDrivers = [ "modesetting" "radeon" ];

  # X11 session needs QT_IM_MODULE/XMODIFIERS, which waylandFrontend=true omits.
  i18n.inputMethod.fcitx5.waylandFrontend = lib.mkForce false;

  users.users.jasonkwh.extraGroups = [ "cdrom" ];

  # Storage tuning layered onto hardware-configuration.nix (kept untouched):
  # ext4 on the P220 — noatime reduces SSD writes; trim via fstrim.
  fileSystems."/" = {
    options = [ "noatime" ];
  };

  # Keep a single authoritative swap definition and prevent duplicate entries
  # from other imported modules from being merged into /etc/fstab.
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-uuid/${swapUuid}";
      discardPolicy = "both";
    }
  ];

  services = {
    # Intel thermal daemon — protects the aging VAIO cooling from hard
    # thermal trips by throttling early.
    thermald.enable = true;
  };
}
