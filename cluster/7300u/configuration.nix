{ config, lib, pkgs, ... }:

let
  nvidiaEgpuModprobeConf = pkgs.writeText "nvidia-egpu-modprobe.conf" ''
    options nvidia NVreg_EnableMSI=0 NVreg_DynamicPowerManagement=0x00 NVreg_EnableResizableBar=0
  '';
in
{
  imports =
    [
      ../common/configuration.nix
    ];

  home-manager.users.jasonkwh = {
    imports = [
      ../common/home.nix
      ../common/home-gui.nix
      ./home.nix
    ];
  };

  time.timeZone = "Australia/Melbourne";

  boot = {
    kernelPackages = pkgs.linuxPackages;

    # Detect the Thunderbolt dock early enough for the eGPU to be present at boot.
    initrd.kernelModules = [ "thunderbolt" ];

    kernelParams = [
      "nowatchdog"
      # Kernel-managed PCIe hotplug; needed so realloc can size Thunderbolt windows.
      "pcie_ports=native"
      # hpmemprefsize is not a valid pci= option (use hpmmioprefsize).
      # hpmemsize=1G is larger than this machine's 32-bit MMIO window
      # (0xb6800000-0xefffffff, ~920MB) and starves I/O + MMIO assignment.
      # GTX 970 still has an I/O BAR; nested TB3/TB5 bridges need 4K I/O windows.
      # pcie_bus_peer2peer forces 128B MPS; TB3 tunnels often drop larger TLPs.
      "pci=assign-busses,hpbussize=0x33,realloc,hpiosize=4K,hpmmiosize=32M,hpmmioprefsize=512M,noaer,pcie_bus_peer2peer"
      "pcie_aspm=off"
      "pcie_port_pm=off"
      "intel_iommu=off"
    ];

    # Stop systemd-modules-load and udev from probing NVIDIA at ~13s.
    # nvidia-egpu-init loads the module at boot with a config that omits this
    # blacklist (`modprobe -C`), so it does not need --force.
    blacklistedKernelModules = [
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
    ];

    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
    };
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  networking = {
    hostName = "jasonkwh-7300u"; # Define your hostname.
  };

  services = {
    xserver = {
      videoDrivers = [ "modesetting" "nvidia" ];
    };
    hardware.bolt.enable = true;
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

    k3s = {
      enable = false;
      role = "agent";
      serverAddr = "https://jasonkwh-7520u.local:6443";
      token = "K107554bc617e907cf70466a0af218deb9c9ae15f18a29b3033da9583b51be61f6e::server:f9a22d3080e522af42b6e380c413b17d";
      extraFlags = [
        "--flannel-iface=wlp58s0"
      ];
    };
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    nvidia = {
      # Intended to avoid NVKMS eGPU timeouts. Not sufficient on its own:
      # PRIME offload forces nvidia-drm.modeset=1 and fbdev=1 in nixpkgs, so
      # those are mkForce'd off below.
      modesetting.enable = false;
      nvidiaSettings = true;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      
      # Prevent Thunderbolt D3cold PCIe bus sleep timeouts
      powerManagement.enable = false;
      powerManagement.finegrained = false;

      moduleParams = {
        nvidia-drm = {
          modeset = lib.mkForce 0;
          fbdev = lib.mkForce 0;
        };
        nvidia = {
          NVreg_EnableResizableBar = 0;
          NVreg_DynamicPowerManagement = "0x00";
          # MSI through Alpine Ridge + a nested TB5 dock often never arrives,
          # so RM waits on interrupts and hits 0x31:0xffff.
          NVreg_EnableMSI = 0;
        };
      };
      
      nvidiaPersistenced = false;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        allowExternalGpu = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:6:0:0";
      };
    };
    graphics.extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  environment.systemPackages = with pkgs; [
    kdePackages.plasma-thunderbolt
  ];

  # Cold-plug at boot and hot-plug after login both fire this.
  # RemainAfterExit must be false so a later dock connect can start the unit again.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nvidia-egpu-init.service"
  '';

  systemd.services.nvidia-egpu-init = {
    description = "Bind NVIDIA driver to Thunderbolt eGPU";
    after = [
      "systemd-modules-load.service"
      "systemd-udevd.service"
      "bolt.service"
    ];
    wants = [ "bolt.service" ];
    restartIfChanged = false;
    stopIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      DefaultDependencies = false;
    };
    path = [ pkgs.kmod pkgs.coreutils pkgs.gnugrep pkgs.findutils ];
    script = ''
      booted=$(readlink -f /run/booted-system)
      current=$(readlink -f /run/current-system)
      if [ "$booted" != "$current" ]; then
        echo "Generation changed without reboot; skipping NVIDIA bind"
        exit 0
      fi

      gpu=""
      for d in /sys/bus/pci/devices/*; do
        if [ -f "$d/vendor" ] && [ "$(cat "$d/vendor")" = "0x10de" ] \
           && [ "$(cat "$d/class")" = "0x030000" ]; then
          gpu="$d"
          break
        fi
      done
      if [ -z "$gpu" ]; then
        echo "No NVIDIA VGA device found; skipping"
        exit 0
      fi
      echo "Using GPU $gpu"

      if lsmod | grep -q '^nvidia'; then
        echo "Unloading leftover NVIDIA modules"
        rmmod nvidia_drm nvidia_modeset nvidia_uvm nvidia || true
      fi
      if [ -e "$gpu/driver" ]; then
        echo "$(basename "$gpu")" > "$gpu/driver/unbind" || true
      fi

      # Let Thunderbolt finish BAR setup on hotplug before RM probe.
      sleep 3

      kver=$(uname -r)
      # kmod -d replaces /lib/modules, so pass the directory that contains $kver.
      modroot=/run/booted-system/kernel-modules/lib/modules
      echo "kver=$kver modroot=$modroot"
      ls -la "$modroot/$kver" || true
      find "$modroot/$kver" -name 'nvidia.ko*' -print || true

      echo "Loading nvidia.ko"
      modprobe -d "$modroot" -C ${nvidiaEgpuModprobeConf} -v nvidia
    '';
  };
}
