
{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ../../hardware-configuration.nix
    ../common/configuration.nix
  ];

  hardware.enableRedistributableFirmware = true;

  boot = {
    # Fix for Realtek RTL8821CE intermittent disconnections
    extraModprobeConfig = ''
      options rtw88_core disable_lps_deep=Y disable_lps=Y
      options rtw88_pci disable_msi=Y disable_aspm=Y
      options rtw88_8821ce disable_lps_deep=Y disable_lps=Y
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
      enable = true;
      role = "server"; # or agent
      # serverAddr = "https://192.168.50.83:6443";
      # token = "";
      extraFlags = toString [
        # "--kubelet-arg=v=4" # Optionally add additional args to k3s
      ];
    };

    # use evtest to find out the device id & key num
    udev.extraHwdb = ''
      evdev:atkbd:*
        KEYBOARD_KEY_56=leftshift
    '';
  };
}