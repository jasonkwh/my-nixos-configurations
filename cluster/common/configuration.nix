# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, username, fullName, email, homeDirectory, isLaptop ? false, isHeadless ? false, hardwareConfig, hermesPeerHosts, hostDefs, syncthingDevices, ... }:

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

  imports = [ hardwareConfig ]
    ++ lib.optionals isLaptop [ ./laptop.nix ]
    ++ lib.optionals isHeadless [ ./headless.nix ./tailscale-enrol.nix ./wifi-home.nix ];

  # Bootloader.
  boot = {
    zfs.forceImportRoot = false; # silence evaluation warning; safer default (26.11+)
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

    # Builders: opt-in via isBuilder, and only serve their own arch.
    # No self-entry (local builds stay local). Tailscale SSH handles auth.
    distributedBuilds = true;
    buildMachines =
      let
        tsDomain = "tail0c0276.ts.net";
        builders = lib.filterAttrs (_: def:
          def.isBuilder or false && def.hostSystem == pkgs.stdenv.hostPlatform.system) hostDefs;
        mkBuilder = host: def: {
          hostName = "${host}.${tsDomain}";
          sshUser = username;
          system = def.hostSystem;
          maxJobs = def.maxBuildJobs;
          speedFactor = def.buildSpeed;
          supportedFeatures = [ "kvm" "big-parallel" "nixos-test" ];
        };
      in
      lib.filter (m: m.hostName != "${config.networking.hostName}.${tsDomain}")
        (lib.mapAttrsToList mkBuilder builders);
  };

  networking.wireless.enable = lib.mkIf isHeadless true;

  networking = {
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    # Headless boards take wlan0 away from NetworkManager (wpa_supplicant
    # owns it via common/wifi-home.nix); NM keeps eth0 and the desktops.
    networkmanager.unmanaged = lib.mkIf isHeadless [ "wlan0" ];
    networkmanager = {
      enable = true; # Enable networking
      dns = "none";

    };
  };

  # Permit direct Resilio peers only over the private Tailscale interface;
  # do not expose the sync port on public/Wi-Fi interfaces.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      22 # fleet ssh (key-only)
      8642 # hermes agent-to-agent (peer dm)
    ];
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
      "electron-39.8.10"
    ];
  };

  # System tools that require root/polkit integration.
  # System-level Brave wrapper with a CDP debugging port for the Hermes
  # browser tools (on-demand, headless-capable). Lives in the system PATH so
  # the `hermes` service user can run it without sudo. A separate
  # --user-data-dir is mandatory: Chromium 136+ silently refuses
  # --remote-debugging-port on the default profile.
  environment.systemPackages = with pkgs; [
    (runCommand "shengos-branding" { } ''
      mkdir -p $out/share/pixmaps
      cp ${../../assets/logos/logo.png} $out/share/pixmaps/shengos.png
    '')
    (writeShellScriptBin "brave-debug" ''
      exec ${brave}/bin/brave \
        --remote-debugging-port=9222 \
        --user-data-dir=''${BRAVE_DEBUG_DIR:-$HOME/.hermes/brave-debug} \
        ''${BRAVE_DEBUG_EXTRA_ARGS:-} "$@"
    '')
    (writeShellScriptBin "meow" ''
      exec ${gnumake}/bin/make -C ${homeDirectory}/Documents/my-nixos-configurations "$@"
    '')
    tcpdump
    pciutils
    smartmontools
    ]
    ++ lib.optionals (!isHeadless) [ wineWow64Packages.full winetricks kdePackages.partitionmanager ]
    ++ [
    htop
    direnv
    ripgrep
  ];

  # Run the interactive CLI as the service account so its state remains private
  # and all files under HERMES_HOME have consistent ownership.
  environment.shellAliases.hermes =
    "sudo -u hermes ${pkgs.coreutils}/bin/env HERMES_HOME=/var/lib/hermes/.hermes hermes";


  # Passwordless sudo for the hermes service user, scoped to exact binaries.
  # Wrappers are installed into the system PATH under fixed names; the
  # sudoers entries reference their stable /run/current-system/sw/bin paths,
  # so nixpkgs updates never break the match (store paths would drift).
  security.sudo.extraRules = let
    sudoCmd = name: {
      command = "/run/current-system/sw/bin/${name} *";
      options = [ "NOPASSWD" ];
    };
  in [
    {
      users = [ "hermes" ];
      commands = map sudoCmd [ "nixos-rebuild" "nix-collect-garbage" "nix-env" ];
    }
  ];

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

    # Gamemode: temporarily boosts CPU governor and process priority during
    # gaming. Inert unless launched via gamemoderun. GPU tuning is host-specific.
    gamemode = {
      enable = true;
      settings.general.renice = 10;
    };

    # Steam client, available on every machine in the fleet.
    steam.enable = true;
  };

  # List services that you want to enable:

  security.pam.services.sddm.enableKwallet = true;

  services = {
    tailscale.enable = true;
    # Fleet SSH goes through Tailscale SSH (identity-based, no keys);
    # public key auth stays off in services.openssh below.
    tailscale.extraSetFlags = [ "--ssh" ];

    # Peer-to-peer sync of Hermes' memories and skills across the fleet.
    # Replaces the previous Resilio (services.resilio) setup, which never
    # paired reliably. Syncthing discovers devices automatically over LAN
    # and Tailscale — no known_hosts pinning or shared secrets to copy.
    syncthing = {
      enable = true;
      user = "hermes";
      group = "hermes";
      dataDir = "/var/lib/syncthing-hermes";
      configDir = "/var/lib/syncthing-hermes/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        options = {
          # Fleet is always behind Tailscale; no need for global
          # discovery/relay/NAT traversal.
          globalAnnounceEnabled = false;
          localAnnounceEnabled = true;
          relaysEnabled = false;
          natEnabled = false;
          urAccepted = -1;
        };
        # Pin peers by MagicDNS name (not raw 100.x IPs — those can change).
        # "dynamic" discovery alone is not enough: local broadcast doesn't
        # cross the Tailscale interface and global announce is disabled.
        # Addresses are derived from the device hostname + tailnet domain,
        # so adding a fleet member only requires its device id above.
        devices = builtins.mapAttrs
          (name: dev:
            dev // {
              addresses = [ "tcp://${name}.tail0c0276.ts.net:22000" ];
            })
          syncthingDevices;
        folders = let
          # Every fleet member syncs every folder; versioning keeps a
          # 14-day trashcan on both.
          allDevices = builtins.attrNames syncthingDevices;
          folderVersioning = {
            type = "trashcan";
            fsType = "simple";
            params.cleanoutDays = "14";
          };
        in {
          # ignorePerms: sync content, not permission bits — syncthing's
          # chmod pass fails on dirs with per-host gids/ACLs.
          hermes-memories = {
            path = "/var/lib/hermes/.hermes/memories";
            devices = allDevices;
            versioning = folderVersioning;
            ignorePerms = true;
          };
          hermes-skills = {
            path = "/var/lib/hermes/.hermes/skills";
            devices = allDevices;
            versioning = folderVersioning;
            ignorePerms = true;
          };
        };
      };
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
        himalaya
      ];
      # Personal WhatsApp account: self-chat mode, restricted to Jason's number.
      # The gateway itself is host-specific (only one machine may hold the
      # WhatsApp session at a time) — see cluster/<host>/configuration.nix.
      # The home channel, however, is fleet-wide: cron/notifications should
      # resolve to the same chat no matter which host fires them.
      environment = {
        WHATSAPP_HOME_CHANNEL_NAME = "Jason's ShengOS";
        WHATSAPP_MODE = "self-chat";
        HIMALAYA_CONFIG = "${homeDirectory}/.config/himalaya/config.toml";
        HERMES_MACHINE_IDENTITY = "xiaoshengsheng @ ${config.networking.hostName}";
      };
      # WHATSAPP_HOME_CHANNEL and WHATSAPP_ALLOWED_USERS live in
      # ~/.secrets/hermes-env (environmentFiles below) — keep personal
      # identifiers out of this repo so it can be published safely.
      settings = {
        # Keep the generated config stamped with the schema version expected by
        # the pinned Hermes Agent input, avoiding a perpetual migration warning.
        _config_version = 38;

        agent = {
          api_max_retries = 6;
        };

        model = {
          provider = "openrouter";
          default = "z-ai/glm-5.3-flash";
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
        web = {
          # Tavily key (TAVILY_API_KEY) is in ~/.secrets/hermes-env.
          search_backend = "tavily";
          extract_backend = "tavily";
        };
        browser = {
          cdp_url = "http://127.0.0.1:9222";
          backend = "off";
        };

        # Agent-to-agent: peer gateways over tailscale (api_server on :8642).
        # Peer keys are HERMES_PEER_<NAME>_KEY in ~/.secrets/hermes-env.
        bot_peers = builtins.listToAttrs (map
          (host: lib.nameValuePair host {
            url = "http://${host}.tail0c0276.ts.net:8642";
          })
          (lib.filter (h: h != config.networking.hostName) hermesPeerHosts));
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

    openssh = {
      enable = true; # Enable the OpenSSH daemon.
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "no";
        # Key-only fleet: machines reach each other over Tailscale with
        # per-host identity keys declared in cluster/<host>/configuration.nix.
        PasswordAuthentication = false;
        # Separate PAM-backed door; must match PasswordAuthentication or
        # passwords re-enter via keyboard-interactive.
        KbdInteractiveAuthentication = false;
      };
      # Port 22 stays shut on LAN/WLAN; tailnet-only reachability below.
      openFirewall = false;
    };

  };

  hardware = {
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Bluetooth is a general-machine capability (Mac Pro trashcan has it too);
    # hosts without BT can override with mkForce false.
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

    '';
  };

  # Deploy ShengOS's personality (SOUL.md) into Hermes' HERMES_HOME so the
  # agent comes up as 小升升 on every host.  Owned by hermes, read-only it is
  # not overwritten by Hermes' own seed logic on rebuild.
  system.activationScripts.hermes-soul-md = {
    deps = [ "users" ];
    text = ''
      install -o hermes -g hermes -m 0640 \
        ${../misc/SOUL.md} /var/lib/hermes/.hermes/SOUL.md
    '';
  };

  # The syncthing unit's default hardening (PrivateUsers=true + trimmed
  # capability bounding set) puts it in a user namespace that cannot chmod
  # synced dirs — every dir pull fails with "operation not permitted".
  systemd.services.syncthing.serviceConfig.PrivateUsers = lib.mkForce false;

}