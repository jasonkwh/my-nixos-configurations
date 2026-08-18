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
    beekeeper-studio
    postman
    pulumi
    # nixpkgs calls wrapGAppsHook from buildCommand before the fixup phase,
    # where its required $output context is unavailable.  The hook still runs
    # normally during fixup, so remove only the obsolete early invocation.
    (mongodb-compass.overrideAttrs (old: {
      buildCommand = pkgs.lib.replaceStrings [
        "wrapGAppsHook $out/bin/mongodb-compass"
      ] [ "" ] old.buildCommand;
    }))
  ];
}
