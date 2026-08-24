# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, username, fullName, email, homeDirectory, isLive ? false, ... }:

{
  # User-facing operating-system branding.  ShengOS remains NixOS underneath;
  # this controls the identity exposed through /etc/os-release and desktop
  # system-information pages such as KDE's About System.
  system.nixos = {
    # Keep the machine identifiable as NixOS to third-party software while
    # presenting ShengOS as the human-facing distribution name.
    distroName = "ShengOS";
    extraOSReleaseArgs = {
      LOGO = "shengos";
      HOME_URL = "https://github.com/jasonkwh";
    };
  };

  imports = lib.optional (!isLive) /etc/nixos/hardware-configuration.nix;

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

    };

      # Kubernetes firewall rules (enable only when running k8s)
      firewall = {
        allowedTCPPorts = [
          # 6443   # Kubernetes API server (required)
          # 10250  # Kubelet API (optional but recommended for metrics/debugging)
        ];
        allowedUDPPorts = [
          # 8472   # Flannel VXLAN (required for inter-node pod networking)
        ];
      };
  };

  # Permit direct Resilio peers only over the private Tailscale interface;
  # do not expose the sync port on public/Wi-Fi interfaces.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 55555 ];
    allowedUDPPorts = [ 55555 ];
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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

    # Chinese Pinyin input through Fcitx5, shared by both laptops.
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-gtk
          qt6Packages.fcitx5-qt
          qt6Packages.fcitx5-chinese-addons
        ];
      };
    };
  };

  # Use this for the kssshaskpass
  # programs.ssh.askPassword = lib.mkForce "${pkgs.plasma5Packages.ksshaskpass}/bin/ksshaskpass";
  # or this for seahorse
  # programs.ssh.askPassword = lib.mkForce "${pkgs.gnome.seahorse}/libexec/seahorse/ssh-askpass";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    ${username} = {
      isNormalUser = true;
      description = fullName;
      home = homeDirectory;
      extraGroups = [ "networkmanager" "wheel" "podman" ];
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
    (runCommand "shengos-branding" { } ''
      mkdir -p $out/share/pixmaps
      cp ${../../assets/logos/logo.png} $out/share/pixmaps/shengos.png
    '')
    (writeShellScriptBin "meow" ''
      exec ${gnumake}/bin/make -C ${homeDirectory}/Documents/my-nixos-configurations "$@"
    '')
    kdePackages.partitionmanager
    tcpdump
    hw-probe
    wineWow64Packages.full
    winetricks
    htop
    perf
    bpftrace
    direnv
    pciutils
    ripgrep
  ];

  # Run the interactive CLI as the service account so its state remains private
  # and all files under HERMES_HOME have consistent ownership.
  environment.shellAliases.hermes =
    "sudo -u hermes ${pkgs.coreutils}/bin/env HERMES_HOME=/var/lib/hermes/.hermes hermes";


  security.wrappers.bwrap = {
    owner = "root";
    group = "root";
    setuid = true;
    source = "${pkgs.bubblewrap}/bin/bwrap";
  };

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
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.noto
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      source-code-pro
      source-han-mono
    ];

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

    # Share only Hermes' curated long-term memory files.  The secret lives
    # outside this repository and must be copied to every participating host.
    resilio = {
      enable = true;
      enableWebUI = false;
      listeningPort = 55555;
      httpListenAddr = "127.0.0.1";
      httpListenPort = 9000;
      sharedFolders = [
        {
          directory = "/var/lib/hermes/.hermes/memories";
          secretFile = "${homeDirectory}/.secrets/resilio-memories-secret";
          useRelayServer = true;
          useTracker = true;
          useDHT = true;
          searchLAN = true;
          useSyncTrash = true;
          knownHosts = [ ];
        }
      ];
    };

    hermes-agent = {
      enable = true;
      container.enable = false;
      addToSystemPackages = true;
      extraDependencyGroups = [ "messaging" ];
      # Native mode cannot apt/pip install at runtime; these land on the
      # hermes user's PATH for terminal tools, skills, and cron.
      extraPackages = with pkgs; [
        git
        ripgrep
        fd
        file
      ];
      # Personal WhatsApp account: self-chat mode, restricted to Jason's number.
      environment = {
        WHATSAPP_ENABLED = "true";
        WHATSAPP_MODE = "self-chat";
        WHATSAPP_ALLOWED_USERS = "61424495256";
        HIMALAYA_CONFIG = "${homeDirectory}/.config/himalaya/config.toml";
      };
      settings = {
        # Keep the generated config stamped with the schema version expected by
        # the pinned Hermes Agent input, avoiding a perpetual migration warning.
        _config_version = 38;

        model = {
          provider = "openrouter";
          default = "stealth/ox-alpha";
          base_url = "https://openrouter.ai/api/v1";
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          write_approval = true;
        };
        compression = {
          enabled = true;
          threshold = 0.35;
          target_ratio = 0.15;
        };
        display = {
          show_reasoning = false;
        };
        terminal = {
          backend = "local";
        };
      };
      environmentFiles = [
        "${config.users.users.${username}.home}/.secrets/hermes-env"
      ];
    };

    # Periodic SSD TRIM to maintain write performance.
    fstrim = {
      enable = true;
      interval = "weekly";
    };

    # Distribute hardware IRQs across CPU cores.
    irqbalance.enable = true;

    fwupd.enable = true;

    # Required for KDE Discover to manage system packages.
    packagekit.enable = true;


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

  system.activationScripts.hermes-config-access = {
    deps = [ "users" ];
    text = ''
      config_dir=${lib.escapeShellArg "${homeDirectory}/Documents/my-nixos-configurations"}
      secrets_dir=${lib.escapeShellArg "${homeDirectory}/.secrets"}
      himalaya_dir=${lib.escapeShellArg "${homeDirectory}/.config/himalaya"}

      if [ -d "$config_dir" ]; then
        ${pkgs.acl}/bin/setfacl -m u:hermes:--x \
          ${lib.escapeShellArg homeDirectory} \
          ${lib.escapeShellArg "${homeDirectory}/Documents"}
        ${pkgs.acl}/bin/setfacl -R -m u:hermes:rwX "$config_dir"
        ${pkgs.findutils}/bin/find "$config_dir" -type d \
          -exec ${pkgs.acl}/bin/setfacl -m d:u:hermes:rwX {} +
      fi

      # Allow the Hermes service user to use the declarative Himalaya setup.
      # The Gmail app password remains in Jason's secrets directory; this
      # grants Hermes only the minimum traversal/read access required by the
      # Himalaya passwordCommand and configured file.
      if [ -d "$secrets_dir" ] && [ -d "$himalaya_dir" ]; then
        ${pkgs.acl}/bin/setfacl -m u:hermes:--x \
          ${lib.escapeShellArg homeDirectory} "$secrets_dir" \
          ${lib.escapeShellArg "${homeDirectory}/.config"}
        ${pkgs.acl}/bin/setfacl -m u:hermes:rx "$himalaya_dir"
        # config.toml is a Home Manager symlink into /nix/store, which is
        # already readable and must not be modified by setfacl.
        [ ! -f "$secrets_dir/gmail-app-password" ] || \
          ${pkgs.acl}/bin/setfacl -m u:hermes:r "$secrets_dir/gmail-app-password"
      fi

      # Resilio reads its shared-folder secret from Jason's private secrets
      # directory.  Grant rslsync only traversal plus read access to this one
      # file; keep the secret itself outside the repository.
      if [ -d "$secrets_dir" ]; then
        ${pkgs.acl}/bin/setfacl -m u:rslsync:--x \
          ${lib.escapeShellArg homeDirectory} "$secrets_dir"
        [ ! -f "$secrets_dir/resilio-memories-secret" ] || \
          ${pkgs.acl}/bin/setfacl -m u:rslsync:r "$secrets_dir/resilio-memories-secret"
      fi
    '';
  };

  # Resilio runs as rslsync while Hermes runs as hermes.  Keep the shared
  # memory directory writable by both without broadening access to HERMES_HOME.
  system.activationScripts.resilio-hermes-memory-access = {
    deps = [ "users" ];
    text = ''
      memory_dir=/var/lib/hermes/.hermes/memories
      if [ -d "$memory_dir" ]; then
        ${pkgs.coreutils}/bin/chgrp -R rslsync "$memory_dir"
        ${pkgs.findutils}/bin/find "$memory_dir" -type d \
          -exec ${pkgs.coreutils}/bin/chmod 2770 {} +
        ${pkgs.findutils}/bin/find "$memory_dir" -type f \
          -exec ${pkgs.coreutils}/bin/chmod 0660 {} +

        # Both services must retain access regardless of which one creates a
        # new file.  Default ACLs cover files created after activation.
        ${pkgs.acl}/bin/setfacl -m u:hermes:rwx,u:rslsync:rwx,m:rwx "$memory_dir"
        ${pkgs.findutils}/bin/find "$memory_dir" -type d \
          -exec ${pkgs.acl}/bin/setfacl -m u:hermes:rwx,u:rslsync:rwx,m:rwx,d:u:hermes:rwx,d:u:rslsync:rwx,d:m:rwx {} +
        ${pkgs.findutils}/bin/find "$memory_dir" -type f \
          -exec ${pkgs.acl}/bin/setfacl -m u:hermes:rw,u:rslsync:rw,m:rw {} +
      fi
    '';
  };

  # Deploy ShengOS's personality (SOUL.md) into Hermes' HERMES_HOME so the
  # agent comes up as 小升升 on every host.  Owned by hermes, read-only it is
  # not overwritten by Hermes' own seed logic on rebuild.
  system.activationScripts.hermes-soul-md = {
    deps = [ "users" ];
    text = ''
      install -o hermes -g hermes -m 0640 \
        ${./SOUL.md} /var/lib/hermes/.hermes/SOUL.md
    '';
  };

  # GitHub Actions self-hosted runner (see README for setup)
  services.github-runners.${config.networking.hostName} = {
    enable = true;
    url = "https://github.com/jasonkwh/my-nixos-configurations";
    tokenFile = "${config.users.users.${username}.home}/.secrets/github-runner-token";
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
        "${pkgs.bash}/bin/bash -c 'TOKEN=$(cat ${config.users.users.${username}.home}/.secrets/github-runner-token); if [ ! -d /var/lib/nixos-config/.git ]; then git clone https://x-access-token:$TOKEN@github.com/jasonkwh/my-nixos-configurations.git /var/lib/nixos-config; else cd /var/lib/nixos-config && git remote set-url origin https://x-access-token:$TOKEN@github.com/jasonkwh/my-nixos-configurations.git && git pull; fi'"
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