{ lib, pkgs, username, ... }:

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

  networking.hostName = "jasonkwh-7300u";

  services = {
    xserver.videoDrivers = [ "modesetting" ];
    thermald.enable = true;

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

    # k3s = {
    #   enable = false;
    #   role = "agent";
    #   serverAddr = "https://jasonkwh-7520u.local:6443";
    #   token = "";
    #   extraFlags = [
    #     "--flannel-iface=wlp58s0"
    #   ];
    # };
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics.extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
}
