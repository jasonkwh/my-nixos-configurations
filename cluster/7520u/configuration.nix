{ config, lib, pkgs, username, ... }:
let
  swapUuid = "97c60ea8-adcf-444b-a44d-e9eeac24138f";
  wifiIface = "wlp2s0";
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

  networking.hostName = "jasonkwh-7520u";

  # This laptop's WhatsApp self-chat is the home channel for cron/notifications.
  services.hermes-agent.environment = {
    WHATSAPP_HOME_CHANNEL = "REDACTED_HOME_CHANNEL";
    WHATSAPP_HOME_CHANNEL_NAME = "jasonkwh-7520u";
  };

  programs = {
    wireshark.enable = true;
  };

  services = {
    xserver.videoDrivers = [ "amdgpu" ];

    # k3s = {
    #   enable = false;
    #   role = "server";
    #   extraFlags = toString [
    #     "--tls-san=${config.networking.hostName}"
    #     "--flannel-iface=${wifiIface}"
    #     "--disable-network-policy"
    #   ];
    # };

    # use evtest to find out the device id & key num
    udev.extraHwdb = ''
      evdev:atkbd:*
        KEYBOARD_KEY_56=leftshift
    '';
  };
}
