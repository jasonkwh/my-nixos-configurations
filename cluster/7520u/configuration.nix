
{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/configuration.nix
  ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ./home.nix
    ];
  };

  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelModules = [ "nft_expr_counter" ];

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
    ];
  };

  networking = {
    hostName = "jasonkwh-7520u"; # Define your hostname.
    networkmanager.wifi.powersave = false;
  };

  services = {
    xserver = {
      videoDrivers = [ "amdgpu" ];
    };

    k3s = {
      enable = false;
      role = "server"; # or agent
      # serverAddr = "https://192.168.50.83:6443";
      # token = "";
      extraFlags = toString [
        "--tls-san=${config.networking.hostName}"
        "--flannel-iface=wlp2s0"
        "--disable-network-policy"
      ];
    };

    avahi = {
      enable = true;
      nssmdns4 = true;  # Enable mDNS name resolution in the NSS layer
      publish = {
        enable = true;
        addresses = true;  # Publish the host's IP addresses
        workstation = true;  # Publish the workstation service
      };
    };

    # use evtest to find out the device id & key num
    udev.extraHwdb = ''
      evdev:atkbd:*
        KEYBOARD_KEY_56=leftshift
    '';
  };
}
