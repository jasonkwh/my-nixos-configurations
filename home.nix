{ config, pkgs, ... }:

{
  home.username = "jasonkwh";
  home.homeDirectory = "/home/jasonkwh";

  programs = {
    # basic configuration of git, please change to your own
    git = {
      enable = true;
      userName = "Jason Huang";
      userEmail = "jasonkwh@gmail.com";
    };

    zsh = {
      enable = true;
      shellAliases = {
        ll = "ls -l --color=auto";
        kc = "kubectl";
        python = "python3";
        vi = "nvim";
        neofetch = "fastfetch";
      };
      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };
      initExtra = "
        export KUBECONFIG=~/.kube/config
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
    timeshift
    graphviz
    postman
    mongodb-compass

    # k8s
    kubectl
    kubectx
    k9s

    # programming
    neovim
    gh
    go_1_23
    cargo
    rustc
    python3
    vscode
    kate

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
