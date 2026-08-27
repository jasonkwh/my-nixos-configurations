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
      # migrated from system packages
      samba
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
