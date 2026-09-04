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
        useOSProber = true;
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

    # i5-2450M is Sandy Bridge (32nm, HD 3000 iGPU); leave the default
    # kernel in place but keep power management conservative.
    kernelParams = [
      # Radeon HD6630M (TeraScale 2) DPM: old vbios on this switchable-graphics
      # VAIO can mis-clock the dGPU (flicker/blank screen). Start in "battery"
      # profile for stability; raise to "performance" only while gaming via
      # /sys/class/drm/card1/device/power_dpm_force_performance_level.
      "radeon.dpm=1"
    ];
  };

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # VA-API for the Sandy Bridge iGPU (32-bit GL & base mesa come from common).
    graphics.extraPackages = with pkgs; [
      intel-vaapi-driver # Sandy Bridge uses the legacy driver
    ];
  };

  # vainfo / GPU diagnostics.
  environment.systemPackages = with pkgs; [
    libva-utils
  ];

  # Hybrid graphics: HD3000 iGPU handles the desktop; the Radeon HD6630M
  # (TeraScale 2 — amdgpu does NOT support it, the legacy `radeon` driver
  # is required) is used on demand via PRIME render offload:
  #   DRI_PRIME=1 <game>        (or `DRI_PRIME=1 %command%` in Steam)
  # modesetting covers the Intel iGPU (xf86-video-intel is abandoned and
  # buggy); radeon DDX claims the AMD dGPU. Each driver only matches its
  # own hardware.
  services.xserver.videoDrivers = [ "modesetting" "radeon" ];

  # Lets desktop launchers offer per-app GPU selection.
  services.switcherooControl.enable = true;

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

    # Touchpad tuning (same feel as 7300u): tap-to-click, natural scrolling,
    # two-finger scroll, no cursor jumps while typing.
    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        scrollMethod = "twofinger";
        clickMethod = "clickfinger";
        accelProfile = "flat";
        disableWhileTyping = true;
        accelSpeed = "0.0";
      };
    };
  };
}
