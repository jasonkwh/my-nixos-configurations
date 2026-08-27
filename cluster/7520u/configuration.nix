{ config, lib, pkgs, username, ... }:
let
  swapUuid = "97c60ea8-adcf-444b-a44d-e9eeac24138f";
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

  hardware = {
    cpu.amd.updateMicrocode = true;

    graphics.extraPackages = with pkgs; [
      # VA-API and VDPAU for hardware video decode/encode (mpv, ffmpeg, browser video)
      mesa
      libva-utils
      rocmPackages.clr.icd
    ];
  };

  boot = {
    # Resume hibernation image from the 7520u swap partition.
    resumeDevice = "/dev/disk/by-uuid/${swapUuid}";

    # Fix for Realtek RTL8821CE intermittent disconnections
    extraModprobeConfig = ''
      options rtw88_core disable_lps_deep=Y disable_lps=Y
      options rtw88_pci disable_msi=Y disable_aspm=Y
      options rtw88_8821ce disable_lps_deep=Y disable_lps=Y ant_sel=2
    '';

    kernelParams = [
      "pcie_aspm.policy=performance"
      "pci=noaer"
      "iwlwifi.power_save=0"
      "rtw88_core.disable_lps_deep=Y"
      "rtw88_pci.disable_msi=Y"
      # Work around amdgpu/KWin pageflip timeout hangs on this laptop.
      "amdgpu.dcdebugmask=0x10"
      # Use the modern AMD P-State driver for better CPU frequency scaling
      "amd_pstate=active"
    ];
  };

  # Keep a single authoritative swap definition and prevent duplicate entries
  # from other imported modules from being merged into /etc/fstab.
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-uuid/${swapUuid}";
      discardPolicy = "both";
    }
  ];

  # Fleet access: Jason's personal key (the same key on every ShengOS host).
  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDt+8OZmQmY/A9wF0vsw5BChq9N7P6B2li2uAnmMu0nU jasonkwh-bcm2711-firstboot"
  ];

  networking.hostName = "jasonkwh-7520u";

  # Storage tuning layered onto hardware-configuration.nix (kept untouched):
  # NVMe btrfs wants noatime + transparent zstd compression (space and less
  # write amplification); ssd/discard=async are auto-derived by btrfs.
  # Hibernation is unaffected: resumeDevice above stays the raw swap UUID.
  fileSystems."/" = {
    options = [ "noatime" "compress=zstd" ];
  };


  # WhatsApp gateway switch: only one machine in the fleet may hold the
  # session at a time (same number would fight otherwise). Currently 7520u.
  services.hermes-agent.environment.WHATSAPP_ENABLED = "true";

  programs = {
    wireshark.enable = true;
  };

  services = {
    xserver.videoDrivers = [ "amdgpu" ];

    # use evtest to find out the device id & key num
    udev.extraHwdb = ''
      evdev:atkbd:*
        KEYBOARD_KEY_56=leftshift
    '';
  };
}
