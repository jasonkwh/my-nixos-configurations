# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
  ];

  # Bootloader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # don't keep too much generations
      };

      efi.canTouchEfiVariables = true;
    };

    kernel.sysctl = {
      # Allow more inotify watchers — Cursor/VSCode language servers use many
      "fs.inotify.max_user_watches" = 524288;
      "fs.inotify.max_user_instances" = 1024;
    };
  };

  nix = {
    settings = {
      sandbox = true;
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      system-features = [ "kvm" ];
      # Use all available CPU cores for parallel Nix builds
      max-jobs = "auto";
      cores = 0;
    };
  };

  networking = {
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    networkmanager = {
      enable = true; # Enable networking
      dns = "none";

      wifi = {
        powersave = false;
      };
    };

    # Kubernetes firewall rules (uncomment if running k8s)
    firewall = {
      allowedTCPPorts = [
        6443   # Kubernetes API server (required)
        10250  # Kubelet API (optional but recommended for metrics/logs/debugging)
      ];
      allowedUDPPorts = [
        8472   # Flannel VXLAN (required for inter-node pod networking)
      ];
    };
  };
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_AU.UTF-8";

    extraLocaleSettings = {
      LC_ADDRESS = "en_AU.UTF-8";
      LC_IDENTIFICATION = "en_AU.UTF-8";
      LC_MEASUREMENT = "en_AU.UTF-8";
      LC_MONETARY = "en_AU.UTF-8";
      LC_NAME = "en_AU.UTF-8";
      LC_NUMERIC = "en_AU.UTF-8";
      LC_PAPER = "en_AU.UTF-8";
      LC_TELEPHONE = "en_AU.UTF-8";
      LC_TIME = "en_AU.UTF-8";
    };
  };

  # Use this for the kssshaskpass
  # programs.ssh.askPassword = lib.mkForce "${pkgs.plasma5Packages.ksshaskpass}/bin/ksshaskpass";
  # or this for seahorse
  # programs.ssh.askPassword = lib.mkForce "${pkgs.gnome.seahorse}/libexec/seahorse/ssh-askpass";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    jasonkwh = {
      isNormalUser = true;
      description = "Jason Huang";
      extraGroups = [ "networkmanager" "wheel" "podman" "rslsync" ];
      shell = pkgs.zsh;
      subUidRanges = [{ startUid = 100000; count = 65536; }];
      subGidRanges = [{ startGid = 100000; count = 65536; }];
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  nixpkgs.config = {
  # Allow unfree packages
    allowUnfree = true;

    permittedInsecurePackages = [
      "electron-33.4.11"
      "beekeeper-studio-5.3.4"
    ];
  };

  # System tools that require root/polkit integration.
  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager
    tcpdump
    hw-probe
    wineWow64Packages.full
    winetricks
    htop
    perf
    bpftrace
    direnv
  ];

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    # virtualbox = {
    #   host = {
    #     enable = true;
    #     enableExtensionPack = true;
    #   };
    #   guest = {
    #     enable = true;
    #   };
    # };
  };

  fonts = {
    # Font packages are now in home.nix
    fontDir.enable = true;

    fontconfig = {
      enable = true;

      # Fixes pixelation
      antialias = true;

      # Fixes antialiasing blur
      hinting = {
        enable = true;
      };
    };
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1w";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };


  programs = {
    dconf = {
      enable = true;
    };

    zsh = {
      enable = true;
    };

    nix-ld = {
      enable = true;
    };
  };

  # List services that you want to enable:

  security.pam.services.sddm.enableKwallet = true;

  services = {
    tailscale.enable = true;

    # Required for KDE Discover to manage system packages.
    packagekit.enable = true;

    upower = {
      enable = true;
      # If the battery becomes critical, do a clean shutdown instead of
      # entering a potentially unrecoverable low-power suspend state.
      criticalPowerAction = "PowerOff";
    };

    # Use KWallet as the single secrets backend on KDE.
    gnome.gnome-keyring.enable = false;

    displayManager = {
      sddm = {
        enable = true;
      };
    };
      
    desktopManager = {
      plasma6 = {
        enable = true;
        enableQt5Integration = true;
      };
    };

    xserver = {
      # Enable the X11 windowing system.
      enable = true;

      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    printing = {
      enable = true; # Enable CUPS to print documents.
      openFirewall = true;
    };

    flatpak = {
      enable = true;
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

    openssh = {
      enable = true; # Enable the OpenSSH daemon.
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "yes";
        PasswordAuthentication = true;
      };
      openFirewall = true;
    };

    logind = {
      settings = {
        Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchDocked = "ignore";
          HandleLidSwitchExternalPower = "ignore";
        };
      };
    };
  };

  # Avahi can occasionally leave a stale PID file in /run after abrupt exits,
  # which causes switch-to-configuration to fail on service restart.
  systemd.services.avahi-daemon.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/rm -f /run/avahi-daemon/pid"
  ];

  hardware = {    
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    steam-hardware = {
      enable = true;
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  system.activationScripts.flathub-remote = ''
    ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >&2
  '';

  # GitHub Actions self-hosted runner (see README for setup)
  services.github-runners.${config.networking.hostName} = {
    enable = true;
    url = "https://github.com/jasonkwh/my-nixos-configurations";
    tokenFile = "/etc/github-runner-token";
    user = "root";
    replace = true;
    extraLabels = [ "nixos" config.networking.hostName ];
    extraPackages = with pkgs; [
      nixVersions.latest
      git
      gnumake
      systemd
    ];
  };

  # NixOS rebuild service - runs outside GitHub runner's restricted context
  systemd.services.nixos-rebuild-switch = {
    description = "NixOS Rebuild Switch";
    path = [ pkgs.git pkgs.nix pkgs.nixos-rebuild ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/var/lib/nixos-config";
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c 'TOKEN=$(cat /etc/github-runner-token); if [ ! -d /var/lib/nixos-config/.git ]; then git clone https://x-access-token:$TOKEN@github.com/jasonkwh/my-nixos-configurations.git /var/lib/nixos-config; else cd /var/lib/nixos-config && git remote set-url origin https://x-access-token:$TOKEN@github.com/jasonkwh/my-nixos-configurations.git && git pull; fi'"
        "${pkgs.nix}/bin/nix flake update --flake /var/lib/nixos-config"
      ];
      ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /var/lib/nixos-config#${config.networking.hostName} --impure --accept-flake-config";
      RemainAfterExit = false;
    };
  };

  # Create the config directory
  systemd.tmpfiles.rules = [
    "d /var/lib/nixos-config 0755 root root -"
  ];
}