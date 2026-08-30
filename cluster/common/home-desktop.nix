# Desktop-only Home Manager bits: Plasma, GUI apps, secret service,
# autostart. Imported by common/home.nix only when !isHeadless.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Cursor startup flags (equivalent to "Preferences: Configure Runtime Arguments"):
  # - enable-crash-reporter=false: skip Sentry crash-reporter background process
  # - disable-hardware-acceleration=true: avoid Electron GPU crashes while keeping sandboxing enabled
  home.file.".config/Cursor/argv.json".text = builtins.toJSON {
    "disable-hardware-acceleration" = true;
    "enable-crash-reporter" = false;
    "enable-proposed-api" = [];
  };

  # Silence Qt Multimedia startup noise (e.g. Dolphin):
  # "qt.multimedia.symbolsresolver: Couldn't load pipewire-0.3 library".
  # QtMultimedia dlopens libpipewire-0.3 on init; on NixOS the default
  # dlopen search path can't see it, so it logs a warning. PipeWire
  # itself runs fine (pipewire-pulse handles audio); this is pure noise.
  home.file.".config/QtProject/qtlogging.ini".text = ''
    [Rules]
    qt.multimedia.symbolsresolver=false
  '';

  # KWallet-only setup: keep Secret Service API enabled (desktop hosts only).
  home.file.".config/kwalletrc".text = ''
    [org.freedesktop.secrets]
    apiEnabled=true
  '';

  xdg.autostart.enable = true;

  # KDE Plasma configuration (using plasma-manager).
  programs.plasma = {
    enable = true;

    # Use Breeze Dark theme
    workspace = {
      wallpaper = ../../assets/wallpapers/DSCF4098.JPG;
      lookAndFeel = "org.kde.breezedark.desktop";
      colorScheme = "BreezeDark";
    };

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

  # GUI apps shared by desktop hosts (several have no aarch64 build, e.g. zoom-us).
  home.packages = with pkgs;
    [
      gh
      # k8s toolchain — desktop only; kept out of home-headless so ARM
      # images don't build kubectl for aarch64 (bcm2710a1 image, 2026-08-31).
      kubectl
      kubectx
      k9s
      kubelogin
      kustomize
      # cloud/devops toolchains — same reason; nothing on the Pi needs them.
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
      libreoffice-qt
      zoom-us
      brave
      code-cursor
      buildah
      skopeo
      ollama
      podman-compose
    ];

  # kc=kubectl alias rides along with the k8s tools (zsh itself is
  # configured in home-headless.nix).
  programs.zsh.shellAliases = lib.mkIf config.programs.zsh.enable {
    kc = "kubectl";
  };

  # Automatically run podman system migrate after home-manager activation
  home.activation.podmanMigrate = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if command -v podman &> /dev/null; then
      ${pkgs.podman}/bin/podman system migrate 2>/dev/null || true
    fi
  '';
}
