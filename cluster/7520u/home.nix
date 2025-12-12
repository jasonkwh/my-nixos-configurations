{ config, pkgs, ... }:

let
  cursor = pkgs.appimageTools.wrapType2 {
    pname = "cursor";
    version = "2.2.17";

    src = pkgs.fetchurl {
      url = "https://downloads.cursor.com/production/cf858ca030e9c9a99ea444ec6efcbcfc40bfda75/linux/x64/Cursor-2.2.17-x86_64.AppImage";
      # use pkgs.lib.fakeSha256 to avoid downloading the file
      sha256 = "sha256-8TTNIGlatkHE8O87h8VGevjaiyWDR8qq8PA7l64Bijs=";
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
    cursor
    ffmpeg
    shntool
    flac
    yq
    distrobox
    boxbuddy

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
