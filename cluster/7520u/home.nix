{ config, pkgs, ... }:

{
  home.file.".config/powermanagementprofilesrc" = {
    text = ''
      [AC]
      lidAction=0

      [Battery]
      lidAction=0

      [LowBattery]
      lidAction=0
    '';
    force = true;
  };

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
    sunshine
  ];
}
