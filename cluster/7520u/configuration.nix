{ lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ../../hardware-configuration.nix
      ../common/configuration.nix
    ];

  boot = {
    # Fix for Realtek RTL8821CE intermittent disconnections
    extraModprobeConfig = ''
      options rtw88_core disable_lps_deep=Y
      options rtw88_pci disable_msi=Y disable_aspm=Y
    '';
    
    kernelParams = [
      "pcie_aspm.policy=performance"
      "pci=noaer"
    ];
  };

  networking = {
    hostName = "jasonkwh-7520u"; # Define your hostname.
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