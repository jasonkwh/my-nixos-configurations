# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  linuxKernel = import ./kernel.nix { inherit pkgs; };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot = {
    kernelPackages = linuxKernel;

    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # don't keep too much generations
      };

      efi.canTouchEfiVariables = true;
    };
  };

  nix = {
    settings = {
      sandbox = true;
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      system-features = [ "kvm" ];
    };
  };

  networking = {
    hostName = "nixos"; # Define your hostname.

    networkmanager = {
      enable = true; # Enable networking
    };

    firewall = {
      allowedTCPPorts = [
        # 6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        # 10250 # kubelet metrics
        # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      ];
      allowedUDPPorts = [
        # 8472 # k3s, flannel: required if using multi-node for inter-node networking
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
      extraGroups = [ "networkmanager" "wheel" "podman" ];
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    xwayland
    gparted
    coreutils
    gcc
    gdb
    gnumake
    binutils
    bc
    file
    nixVersions.latest
  ];

  environment.variables.EDITOR = "vim";

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
    packages = with pkgs; [
      nerdfonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      source-code-pro
      source-han-mono
      source-han-sans
      source-han-serif
      wqy_zenhei
    ];

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


  programs.dconf = {
    enable = true;
  };

  # List services that you want to enable:

  services = {
    displayManager = {
      sddm.enable = true;
    };
      
    desktopManager = {
      plasma6.enable = true;
    };

    xserver = {
      # Enable the X11 windowing system.
      enable = true;

      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };

      videoDrivers = [ "amdgpu" ];
    };

    printing = {
      enable = true; # Enable CUPS to print documents.
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

    k3s = {
      enable = false;
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

  hardware = {    
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

}
