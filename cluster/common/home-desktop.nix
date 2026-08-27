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
      libreoffice-qt
      zoom-us
      brave
      code-cursor
    ];
}
