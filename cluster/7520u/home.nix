{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
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

    # games
    heroic
    protonup-qt
  ];
}
