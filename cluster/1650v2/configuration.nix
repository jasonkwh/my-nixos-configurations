{ lib, pkgs, username, config, ... }:

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

  # Mac Pro 2013 (trashcan) support, per the Debian wiki page for MacPro6,1:
  # - FirePro D-series (GCN1) via modern amdgpu with DC, dpm off (stability);
  # - intel_iommu=off fixes random crashes;
  # - mbpfan: Apple SMC fan curve, needed to keep the twin fans cooling.
  #   https://wiki.debian.org/InstallingDebianOn/Apple/MacPro/6-1
  boot.kernelParams = [ "radeon.si_support=0" "amdgpu.si_support=1" "amdgpu.dc=1" "amdgpu.dpm=0" "intel_iommu=off" ];
  boot.kernelModules = [ "kvm-intel" "applesmc" "coretemp" ];
  services.mbpfan = {
    enable = true;
    settings.general = {
      min_fan1_speed = 900;
      max_fan1_speed = 6200;
      low_temp = 50;
      high_temp = 55;
      max_temp = 65;
      polling_interval = 1;
    };
  };
  boot.extraModulePackages = [
    # BCM4360 (14e4:43a0) Wi-Fi: only the out-of-tree broadcom-wl driver.
    # Best-effort: if the module fails to build against linux_latest this
    # config fails to eval — fall back to Ethernet-only then.
    config.boot.kernelPackages.broadcom_sta
  ];

  services.xserver.videoDrivers = [ "amdgpu" "radeon" "modesetting" ];

  hardware.cpu.intel.updateMicrocode = true;
}
