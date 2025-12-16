{ config, pkgs, ... }:

let
  cursor = import ./cursor.nix { inherit pkgs; };
in
{
  home = {
    username = "jasonkwh";
    homeDirectory = "/home/jasonkwh";

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
      CR_PAT = "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";
      GEMINI_API_KEY = "AIzaSyAzT5eZyvN49MTYMKH_1wYjJiTbjzXanno";
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
      EDITOR = "vim";
    };

    file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm-global
    '';

    # Disable KWallet's Secret Service API so GNOME Keyring handles it
    # (fixes NetworkManager not saving WiFi passwords)
    file.".config/kwalletrc".text = ''
      [org.freedesktop.secrets]
      apiEnabled=false
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
  };

  # Ensure Bluetooth is enabled at login via systemd user service
  systemd.user.services.enable-bluetooth = {
    Unit = {
      Description = "Enable Bluetooth at login";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "enable-bluetooth" ''
        ${pkgs.util-linux}/bin/rfkill unblock bluetooth
        sleep 1
        echo "power on" | ${pkgs.bluez}/bin/bluetoothctl
      ''}";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  programs = {
    # basic configuration of git, please change to your own
    git = {
      enable = true;
      settings = {
        user = {
          email = "jasonkwh@gmail.com";
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
        export PATH=$PATH:$(go env GOPATH)/bin:$HOME/.npm-global/bin

        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        # Wrapper function to run cursor silently
        cursor() {
          command cursor "$@" &>/dev/null &
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
    # utilities
    fastfetch
    tmux
    pigz
    pixz
    htop
    graphviz
    ngrok
    tilt
    golangci-lint
    percona-toolkit
    go-migrate
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
    packet
    warp
    cloc
    azure-cli
    yamllint

    # programming
    neovim
    gh
    go_1_24
    protobuf
    rustup
    python3
    nodejs_24
    php84
    php84Extensions.mysqli
    awscli2
    ssm-session-manager-plugin
    awsebcli
    terraform
    kubernetes-helm
    helmfile
    cursor
    vscode

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
