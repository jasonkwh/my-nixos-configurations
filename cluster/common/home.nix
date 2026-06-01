{ config, pkgs, ... }:

{
  targets.genericLinux.enable = true;

  home = {
    username = "jasonkwh";
    homeDirectory = "/home/jasonkwh";
    sessionPath = [
      "${config.home.homeDirectory}/go/bin"
      "${config.home.homeDirectory}/.npm-global/bin"
    ];

    file.".config/powermanagementprofilesrc" = {
      text = ''
        [AC]
        lidAction=0
      
        [Battery]
        lidAction=0
      
        [LowBattery]
        lidAction=0
      '';
      force = true;
    };

    sessionVariables = {
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
      EDITOR = "vim";
      # Tell all Electron apps (Cursor, VSCode, etc.) to use the native Wayland
      # backend when running under a Wayland compositor, avoiding the XWayland
      # translation layer which adds CPU/GPU overhead and input latency.
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };

    # Cursor startup flags (equivalent to launching with CLI args):
    # - enable-crash-reporter=false: skip Sentry crash-reporter background process
    file.".config/Cursor/argv.json".text = builtins.toJSON {
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

  # KDE Plasma configuration (using plasma-manager)
  programs.plasma = {
    enable = true;
    
    # Use Breeze Dark theme
    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      colorScheme = "BreezeDark";
    };
    
    configFile."kdeglobals"."KDE"."TabletMode" = "Never";

    # Disable Baloo file indexer — it spins at ~40% CPU while indexing
    # dev workspaces. KDE search (Dolphin, KRunner) still works for filenames
    # via locate/fd; only full-text content search is disabled.
    configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  };

  programs = {
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
        [[ -f ~/.secrets/discord-bot-token ]] && export DISCORD_BOT_TOKEN="$(< ~/.secrets/discord-bot-token)"
        [[ -f ~/.secrets/anthropic-api-key ]] && export ANTHROPIC_API_KEY="$(< ~/.secrets/anthropic-api-key)"
        [[ -f ~/.secrets/gemini-api-key ]] && export GEMINI_API_KEY="$(< ~/.secrets/gemini-api-key)"
        [[ -f ~/.secrets/openai-api-key ]] && export OPENAI_API_KEY="$(< ~/.secrets/openai-api-key)"

        # Wrapper function to run cursor silently
        cursor() {
          if command -v nixGLMesa >/dev/null 2>&1; then
            command nixGLMesa cursor "$@" &>/dev/null &
          else
            command cursor "$@" &>/dev/null &
          fi
          disown
        }
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
    fastfetch
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

    # fonts
    nerd-fonts.noto
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    source-code-pro
    source-han-mono
    source-han-sans
    source-han-serif
    wqy_zenhei
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
