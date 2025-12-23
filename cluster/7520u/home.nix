{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    wireshark
    kdePackages.isoimagewriter
    kdePackages.yakuake
    zoom-us
    discord
    slack
    ffmpeg
    shntool
    flac

    # games
    steam
    heroic
    protonup-qt
  ];

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
}
