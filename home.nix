{ config, pkgs, ... }:

{
  home.username = "jasonkwh";
  home.homeDirectory = "/home/jasonkwh";

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = "Jason Huang";
    userEmail = "jasonkwh@gmail.com";
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      kc = "kubectl";
      python = "python3";
      vi = "nvim";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    initExtra = "
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

  programs.bash = {
    enable = true;
    initExtra = "exec zsh";
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # system related
    neofetch
    thefuck
    # vagrant
    buildah
    skopeo
    podman-compose
    tmux
    hw-probe
    pigz
    pixz

    # k8s
    kubectl
    kubectx
    k9s

    # programming
    neovim
    gh
    go_1_22
    cargo
    rustc
    python3
    vscode
    kate

    # fonts
    meslo-lgs-nf

    # internet
    brave
    firefox
    thunderbird

    # games
    steam
    protonup-qt

    # office
    libreoffice-qt
  ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
