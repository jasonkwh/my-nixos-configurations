{ config, pkgs, ... }:

{
  home = {
    username = "jasonkwh";
    homeDirectory = "/home/jasonkwh";

    file.".config/powermanagementprofilesrc".text = ''
      [AC]
      lidAction=0

      [Battery]
      lidAction=0

      [LowBattery]
      lidAction=0
    '';

    sessionVariables = {
      CR_PAT = "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";
      GEMINI_API_KEY = "AIzaSyDH1kTX7Wjon06NzctfcUrO0cJyKwyoN7g";
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
    };

    file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm-global
    '';
  };

  programs = {
    # basic configuration of git, please change to your own
    git = {
      enable = true;
      userName = "Jason Huang";
      userEmail = "jasonkwh@users.noreply.github.com";
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
      initContent = "
        export PATH=$PATH:$(go env GOPATH)/bin:$HOME/.npm-global/bin

        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        eval $(thefuck --alias)
      ";
      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-autosuggestions"; }
          { name = "zsh-users/zsh-syntax-highlighting"; }
          { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
        ];
      };
    };

    bash = {
      enable = true;
      initExtra = "exec zsh";
    };
  };

  xdg.autostart.enable = true;

  xdg.configFile."autostart/yakuake.desktop".source =
    pkgs.writeTextFile {
      name = "yakuake-autostart.desktop";
      text = ''
        [Desktop Entry]
        Type=Application
        Exec=yakuake
        Hidden=false
        NoDisplay=false
        X-GNOME-Autostart-enabled=true
        Name=Yakuake
        Comment=Drop-down terminal
      '';
    };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # utilities
    fastfetch
    thefuck
    # vagrant
    buildah
    skopeo
    podman-compose
    tmux
    hw-probe
    pigz
    pixz
    distrobox
    boxbuddy
    htop
    graphviz
    postman
    mongodb-compass
    ngrok
    isoimagewriter
    mysql-workbench
    tilt
    golangci-lint
    percona-toolkit
    ollama
    go-migrate
    kubectl
    kubectx
    k9s
    kustomize
    lazygit
    act
    tree
    fluxcd
    slack
    eksctl
    openssl
    tcpdump

    # programming
    neovim
    gh
    go_1_23
    protobuf
    rustup
    python3
    vscode
    nodejs_24
    php84
    php84Extensions.mysqli
    awscli2
    ssm-session-manager-plugin
    awsebcli
    terraform
    kubernetes-helm
    helmfile

    # internet
    brave

    # games
    steam
    heroic
    protonup-qt

    # office
    libreoffice-qt
    zoom-us
    discord
  ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
