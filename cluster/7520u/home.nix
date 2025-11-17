{ config, pkgs, ... }:

let
  cursor = pkgs.appimageTools.wrapType2 {
    pname = "cursor";
    version = "1.7.36";

    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/493c403e4a45c5f971d1c76cc74febd0968d57d8/linux/x64/Cursor-1.7.36-x86_64.AppImage";
      sha256 = "sha256-zY9kM9td0yKAMxVmad7saN4c6z2p5OFEa7ScCA3Qo3I=";
    };

    extraPkgs = pkgs: with pkgs; [ ];
  };
in
{
  home.packages = with pkgs; [
    mysql-workbench
    wireshark
    postman
    mongodb-compass
    neo4j-desktop
    kdePackages.isoimagewriter
    kdePackages.yakuake
    libreoffice-qt
    zoom-us
    discord
    slack
    warp-terminal
    cursor
    googleearth-pro
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
