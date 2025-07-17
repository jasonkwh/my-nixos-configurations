{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    mysql-workbench
    wireshark
    postman
    mongodb-compass
    kdePackages.isoimagewriter
    kdePackages.yakuake
    kdePackages.konqueror
    kdePackages.ktorrent
    libreoffice-qt
    zoom-us
    discord
    slack

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
