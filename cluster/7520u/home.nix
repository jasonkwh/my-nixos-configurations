{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    calibre
    vlc
    beekeeper-studio
    postman
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
