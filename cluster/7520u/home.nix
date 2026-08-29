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
    rpi-imager
    beekeeper-studio
    postman
    pulumi
    vscode
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
