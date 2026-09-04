# Desktop-only Home Manager bits: Plasma, GUI apps, secret service,
# autostart. Imported by common/home.nix only when !isHeadless.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Skip Cursor's Sentry crash-reporter and Electron GPU crashes.
  home.file.".config/Cursor/argv.json".text = builtins.toJSON {
    "disable-hardware-acceleration" = true;
    "enable-crash-reporter" = false;
    "enable-proposed-api" = [];
  };

  # QtMultimedia dlopens libpipewire-0.3, invisible on NixOS; harmless noise.
  home.file.".config/QtProject/qtlogging.ini".text = ''
    [Rules]
    qt.multimedia.symbolsresolver=false
  '';

  home.file.".config/kwalletrc".text = ''
    [org.freedesktop.secrets]
    apiEnabled=true
  '';

  xdg.autostart.enable = true;

  programs.plasma = {
    enable = true;

    workspace = {
      wallpaper = ../../assets/wallpapers/DSCF4098.JPG;
      lookAndFeel = "org.kde.breezedark.desktop";
      colorScheme = "BreezeDark";
    };

    # Required for Fcitx5's native Wayland input-method frontend.
    configFile."kwinrc"."Wayland" = {
      InputMethod = {
        shellExpand = true;
        value = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
      };
      VirtualKeyboardEnabled = true;
    };

    # Declared bottom panel, mirroring the existing 7520u layout; only
    # difference is pinning dolphin explicitly instead of preferred://filemanager.
    panels = [
      {
        screen = 0;
        location = "bottom";
        height = 44;
        alignment = "center";
        hiding = "none";
        lengthMode = "fit";
        widgets = [
          {
            name = "org.kde.plasma.kickoff";
            config = {
              "General".systemFavorites = "suspend\\,hibernate\\,reboot\\,shutdown";
            };
          }
          {
            name = "org.kde.plasma.pager";
          }
          {
            name = "org.kde.plasma.icontasks";
            config = {
              "General".launchers =
                "applications:brave-browser.desktop,applications:org.kde.dolphin.desktop,applications:org.kde.konsole.desktop";
            };
          }
          {
            name = "org.kde.plasma.marginsseparator";
          }
          {
            name = "org.kde.plasma.systemtray";
          }
          {
            name = "org.kde.plasma.digitalclock";
            config = {
              "Appearance".fontWeight = 400;
            };
          }
          {
            name = "org.kde.plasma.showdesktop";
          }
        ];
      }
    ];

    # Baloo spins at ~40% CPU indexing dev workspaces.
    configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
  };

  # Desktop-only packages: k8s/cloud/dev toolchains and language stacks
  # live here (not home-headless) so ARM SD images stay lean.
  home.packages = with pkgs;
    [
      kubectl
      kubectx
      k9s
      kubelogin
      kustomize
      grpc
      percona-toolkit
      act
      eksctl
      azure-cli
      awscli2
      ssm-session-manager-plugin
      awsebcli
      terraform
      kubernetes-helm
      helmfile
      pigz
      pixz
      graphviz
      lazygit
      cloc
      yamllint
      img2pdf
      go_1_26
      protobuf
      rustup
      python3
      php84
      php84Extensions.mysqli
      php84Extensions.grpc
      php84Extensions.protobuf
      php84Packages.composer
      tilt
      libreoffice-qt
      zoom-us
      brave
      code-cursor
      buildah
      skopeo
      ollama
      podman-compose
    ];

  # Aliases ride along with the tools they point at (zsh is configured
  # in home-headless.nix).
  programs.zsh.shellAliases = lib.mkIf config.programs.zsh.enable {
    kc = "kubectl";
    python = "python3";
  };

  home.activation.podmanMigrate = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if command -v podman &> /dev/null; then
      ${pkgs.podman}/bin/podman system migrate 2>/dev/null || true
    fi
  '';
}
