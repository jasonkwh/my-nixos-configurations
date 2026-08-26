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

  # 8GB RAM — the tightest desktop in the fleet. Compressed RAM swap gives
  # headroom under memory spikes without touching the (fast NVMe) disk swap.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  # Build aarch64 (bcm2711 SD image) on this x86 host via QEMU emulation:
  # enabled centrally in flake.nix mkHost for x86 non-headless hosts.

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

  # Note: gamemode's GPU optimisations only support NVIDIA and AMD
  # (amd_performance_level / nvidia_powermizer). On this Intel iGPU,
  # gamemode still provides CPU governor boost and renice from common;
  # there is no Intel-specific GPU knob to set here.
}
