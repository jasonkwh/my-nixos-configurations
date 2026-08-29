{ config, pkgs, nixpkgs-master, ... }:

{
  home.packages = with pkgs; [
    discord
    slack
    ffmpeg
    shntool
    flac
    calibre
    vlc
    # 2.0.10 + polkit policy, wired up in cluster/7520u/configuration.nix
    (nixpkgs-master.legacyPackages.${pkgs.stdenv.hostPlatform.system}.rpi-imager)
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
