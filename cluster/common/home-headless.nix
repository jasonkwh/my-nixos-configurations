# Headless-safe core: shared by all hosts; headless boards import only this.
{
  config,
  pkgs,
  lib,
  username,
  fullName,
  email,
  homeDirectory,
  ...
}:

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
    };

    file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm-global
    '';
  };

  accounts.email.accounts.gmail = {
    primary = true;
    address = email;
    realName = fullName;
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
          "terminalfont"
          "cpu"
          "gpu"
          "memory"
          "swap"
          "battery"
          "disk"
          "locale"
          "break"
          "colors"
        ];
        display = {
          separator = " | ";
        };
        logo = {
          source = "${../../assets/logos/logo.png}";
          type = "chafa";
          chafa = {
            symbols = "block+space";
          };
          width = 30;
          height = 22;
          padding = {
            top = 0;
            left = 10;
            right = 10;
            bottom = 0;
          };
        };
      };
    };

    himalaya.enable = true;

    # basic configuration of git, please change to your own
    git = {
      enable = true;
      settings = {
        user = {
          email = email;
          name = fullName;
        };
      };
    };

    zsh = {
      enable = true;
      shellAliases = {
        ll = "ls -lh --color=auto";
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
          { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; }
        ];
      };
    };
  };

  xdg.mimeApps.enable = false;

  fonts.fontconfig.enable = true;

  # CLI toolchains for every host; GUI apps live in ../common/home.nix.
  home.packages = with pkgs;
    [
      # utilities
      tmux
      pigz
      pixz
      graphviz
      lazygit
      tree
      openssl
      cloc
      yamllint
      yq
      img2pdf

      # programming
      neovim
      # migrated from system packages
      git
      vim
      wget

      gcc
      cmake
      gnumake
      binutils
      file
      nixVersions.latest
    ];

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
