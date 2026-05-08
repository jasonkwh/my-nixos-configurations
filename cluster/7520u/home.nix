{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # kdePackages.yakuake
    discord
    slack
    ffmpeg
    shntool
    flac
    calibre
    vlc
    kdePackages.isoimagewriter
    vscode
    beekeeper-studio
    postman
    mongodb-compass
    neo4j-desktop

    # games
    heroic
    protonup-qt
  ];

  # xdg.configFile."autostart/yakuake.desktop".source =
  #   pkgs.writeTextFile {
  #     name = "yakuake-autostart.desktop";
  #     text = ''
  #       [Desktop Entry]
  #       Type=Application
  #       Exec=yakuake
  #       Hidden=false
  #       NoDisplay=false
  #       X-GNOME-Autostart-enabled=true
  #       Name=Yakuake
  #       Comment=Drop-down terminal
  #     '';
  #   };
}
