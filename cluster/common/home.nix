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
      initContent = "
        export PATH=$PATH:$(go env GOPATH)/bin:$HOME/.npm-global/bin

        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
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
  };

  xdg.autostart.enable = true;

  fonts.fontconfig.enable = true;

  

  programs.ncmpcpp = {
    enable = true;
    mpdMusicDir = config.home.homeDirectory + "/Music";
    settings = {
      mpd_host = "127.0.0.1";
      mpd_port = "6600";
      
      # UI settings
      user_interface = "alternative";
      alternative_header_first_line_format = "{$b$2%a$9} $1»$9 {$5%t$9}|{$8%f$9}";
      alternative_header_second_line_format = "{{$6%b$9}{ [$6%y$9]}}|{$6%D$9}";
      
      # Visualizer settings
      visualizer_data_source = "/tmp/mpd.fifo";
      visualizer_output_name = "Visualizer";
      visualizer_in_stereo = "yes";
      visualizer_type = "wave";  # Valid options: "wave", "wave_filled", "ellipse"
      visualizer_look = "●▮";
      visualizer_color = "blue, cyan, green, yellow, magenta, red";
      
      startup_screen = "playlist";
    };
  };

  services.mpd = {
    enable = true;
    musicDirectory = config.home.homeDirectory + "/Music";
    network = {
      listenAddress = "127.0.0.1";
      port = 6600;
    };
    extraConfig = ''
      # Main audio output for listening
      audio_output {
        type "pipewire"
        name "PipeWire"
      }
      
      # FIFO output for visualizer
      audio_output {
        type "fifo"
        name "Visualizer"
        path "/tmp/mpd.fifo"
        format "44100:16:2"
      }
    '';
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # utilities
    fastfetch
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
    ngrok
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
    eksctl
    openssl
    tcpdump
    packet
    mpc
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

    # migrated from system packages
    git
    vim
    wget
    curl
    gparted
    coreutils
    gcc
    # gdb - conflicts with gcc-arm-embedded (which includes its own ARM GDB)
    cmake
    gnumake
    binutils
    gcc-arm-embedded
    picotool
    bc
    file
    nixVersions.latest
    wineWowPackages.full
    winetricks

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

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}