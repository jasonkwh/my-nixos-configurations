{ config, pkgs, username, homeDirectory, ... }:

{
  targets.genericLinux.enable = true;

  home = {
    inherit username homeDirectory;
    sessionPath = [
      "${config.home.homeDirectory}/go/bin"
      "${config.home.homeDirectory}/.npm-global/bin"
    ];

    sessionVariables = {
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
      EDITOR = "vim";
      # Tell all Electron apps (Cursor, VSCode, etc.) to use the native Wayland
      # backend when running under a Wayland compositor, avoiding the XWayland
      # translation layer which adds CPU/GPU overhead and input latency.
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };

    # Cursor startup flags (equivalent to "Preferences: Configure Runtime Arguments"):
    # - enable-crash-reporter=false: skip Sentry crash-reporter background process
    # - disable-hardware-acceleration=true: avoid Electron GPU crashes while keeping sandboxing enabled
    file.".config/Cursor/argv.json".text = builtins.toJSON {
      "disable-hardware-acceleration" = true;
      "enable-crash-reporter" = false;
      "enable-proposed-api" = [];
    };

    file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm-global
    '';

    # KWallet-only setup: keep Secret Service API enabled.
    file.".config/kwalletrc".text = ''
      [org.freedesktop.secrets]
      apiEnabled=true
    '';
  };

  accounts.email.accounts.gmail = {
    primary = true;
    address = "jasonkwh@users.noreply.github.com";
    realName = "Jason Huang";
    flavor = "gmail.com";
    passwordCommand = [
      "${pkgs.coreutils}/bin/cat"
      "${homeDirectory}/.secrets/gmail-app-password"
    ];
    folders = {
      inbox = "INBOX";
      sent = "[Gmail]/Sent Mail";
      drafts = "[Gmail]/Drafts";
      trash = "[Gmail]/Trash";
    };
    himalaya.enable = true;
  };

  # KDE Plasma configuration (using plasma-manager)
  programs.plasma = {
    enable = true;
    
    # Use Breeze Dark theme
    workspace = {
      wallpaper = ../../assets/wallpapers/DSCF4098.JPG;
      lookAndFeel = "org.kde.breezedark.desktop";
      colorScheme = "BreezeDark";
    };
    
    configFile."kdeglobals"."KDE"."TabletMode" = "Never";

    # Have KWin launch Fcitx5 as the Plasma Wayland virtual keyboard.
    # This is required for Fcitx5's native Wayland input-method frontend.
    configFile."kwinrc"."Wayland" = {
      InputMethod = {
        shellExpand = true;
        value = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
      };
      VirtualKeyboardEnabled = true;
    };

    # Disable Baloo file indexer — it spins at ~40% CPU while indexing
    # dev workspaces. KDE search (Dolphin, KRunner) still works for filenames
    # via locate/fd; only full-text content search is disabled.
    configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  };

  programs = {
    fastfetch = {
      enable = true;
      settings = {
        # Defining settings replaces Fastfetch's built-in default configuration,
        # so declare the information modules explicitly as well as the logo.
        modules = [
          "title"
          "separator"
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "display"
          "de"
          "wm"
          "theme"
          "icons"
          "terminal"
          "cpu"
          "gpu"
          "memory"
          "disk"
          "battery"
          "locale"
          "break"
          "colors"
        ];
        logo = {
          source = "${../../assets/logos/logo.png}";
          type = "auto";
        };
      };
    };

    himalaya.enable = true;

    # basic configuration of git, please change to your own
    git = {
      enable = true;
      settings = {
        user = {
          email = "jasonkwh@users.noreply.github.com";
          name = "Jason Huang";
        };
      };
    };

    zsh = {
      enable = true;
      shellAliases = {
        ll = "ls -lh --color=auto";
        kc = "kubectl";
        python = "python3";
        vi = "nvim";
        neofetch = "fastfetch";
      };
      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };
      initContent = ''
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

        # Load secrets from files if they exist
        [[ -f ~/.secrets/github-pat ]] && export CR_PAT="$(< ~/.secrets/github-pat)"
      '';
      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-autosuggestions"; }
          { name = "zsh-users/zsh-syntax-highlighting"; }
          { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
        ];
      };
    };
  };

  xdg = {
    mimeApps.enable = false;
    autostart.enable = true;
  };
  
  fonts.fontconfig.enable = true;

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # migrated from system packages
    samba
    distrobox
    gcc-arm-embedded

    # utilities
    tmux
    pigz
    pixz
    graphviz
    ngrok
    tilt
    percona-toolkit
    kubectl
    kubectx
    k9s
    kubelogin
    kustomize
    lazygit
    act
    tree
    fluxcd
    eksctl
    openssl
    cloc
    azure-cli
    yamllint
    yq
    img2pdf
    ollama

    # programming
    neovim
    gh
    go_1_26
    protobuf
    rustup
    python3
    php84
    php84Extensions.mysqli
    php84Extensions.grpc
    php84Extensions.protobuf
    php84Packages.composer
    grpc
    awscli2
    ssm-session-manager-plugin
    awsebcli
    terraform
    kubernetes-helm
    helmfile
    # migrated from system packages
    git
    vim
    wget
    curl
    coreutils
    gcc
    cmake
    gnumake
    binutils
    bc
    file
    nixVersions.latest
    buildah
    skopeo
    podman-compose
    picotool
  ];

  # Automatically run podman system migrate after home-manager activation
  home.activation.podmanMigrate = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if command -v podman &> /dev/null; then
      ${pkgs.podman}/bin/podman system migrate 2>/dev/null || true
    fi
  '';

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
