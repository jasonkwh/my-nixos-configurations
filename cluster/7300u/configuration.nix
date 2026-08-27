{ lib, pkgs, username, ... }:
let
  swapUuid = "f89a3a65-b8c4-473b-99cd-31ed1436e049";
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

  # Storage tuning layered onto hardware-configuration.nix (kept untouched):
  # NVMe btrfs wants noatime + transparent zstd compression (space and less
  # write amplification); ssd/discard=async are auto-derived by btrfs.
  fileSystems."/" = {
    options = [ "noatime" "compress=zstd" ];
  };

  networking.hostName = "jasonkwh-7300u";

  # Hibernation: resume from the NVMe swap partition (11.8GiB > 8GiB RAM,
  # image always fits).
  boot.resumeDevice = "/dev/disk/by-uuid/${swapUuid}";


  # 8GB RAM — the tightest desktop in the fleet. Compressed RAM swap gives
  # headroom under memory spikes without touching the (fast NVMe) disk swap.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Swap TRIM: mkForce takes over the hardware-config entry (same UUID) so we
  # can attach discardPolicy without stacking a duplicate swap device.
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-uuid/${swapUuid}";
      discardPolicy = "both";
    }
  ];
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
